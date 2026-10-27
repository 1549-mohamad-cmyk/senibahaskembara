-- SeniBahasa Adventure: profile ownership, private quiz keys, server-side grading.
create extension if not exists pgcrypto;
create table if not exists public.profiles(id uuid primary key references auth.users(id) on delete cascade, display_name text not null default '', role text not null default 'student' check(role in ('student','teacher')), created_at timestamptz not null default now());
create table if not exists public.quizzes(id uuid primary key default gen_random_uuid(), title text not null, curriculum text not null default 'SK 4.1 / SP 4.1.1', active boolean not null default true, created_at timestamptz not null default now());
create table if not exists public.questions(id uuid primary key default gen_random_uuid(), quiz_id uuid not null references public.quizzes on delete cascade, ordinal int not null check(ordinal between 1 and 10), level text not null check(level in ('Sukar','Sederhana','Mudah')), prompt text not null, options jsonb not null, answer_index int not null check(answer_index between 0 and 3), feedback text not null, unique(quiz_id,ordinal));
create table if not exists public.sessions(id uuid primary key default gen_random_uuid(), quiz_id uuid not null references public.quizzes, student_id uuid not null references auth.users(id) on delete cascade, status text not null default 'in_progress' check(status in ('in_progress','completed')), current_ordinal int not null default 1 check(current_ordinal between 1 and 11), score int not null default 0 check(score between 0 and 10), started_at timestamptz not null default now(), updated_at timestamptz not null default now(), completed_at timestamptz, unique(quiz_id,student_id,id));
create table if not exists public.submissions(id uuid primary key default gen_random_uuid(), session_id uuid not null references public.sessions on delete cascade, question_id uuid not null references public.questions on delete cascade, student_id uuid not null references auth.users on delete cascade, selected_index int not null check(selected_index between 0 and 3), is_correct boolean not null, submitted_at timestamptz not null default now(), unique(session_id,question_id));
create index if not exists sessions_student_idx on public.sessions(student_id, updated_at desc);
create index if not exists submissions_student_idx on public.submissions(student_id, submitted_at desc);
alter table public.profiles enable row level security; alter table public.quizzes enable row level security; alter table public.questions enable row level security; alter table public.sessions enable row level security; alter table public.submissions enable row level security;
create or replace function public.is_teacher() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='teacher') $$;
create policy "profiles self or teacher read" on public.profiles for select to authenticated using(id=auth.uid() or public.is_teacher());
create policy "profile self insert" on public.profiles for insert to authenticated with check(id=auth.uid() and role='student');
create policy "profile self update name" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid() and role='student');
create policy "active quizzes readable" on public.quizzes for select to authenticated using(active);
-- Deliberately no direct SELECT policy for questions: answer_index is never exposed to client queries.
create policy "student own sessions or teacher" on public.sessions for select to authenticated using(student_id=auth.uid() or public.is_teacher());
create policy "student own submissions or teacher" on public.submissions for select to authenticated using(student_id=auth.uid() or public.is_teacher());
create or replace function public.start_quiz(p_quiz uuid) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_session public.sessions; v_question record;
begin if auth.uid() is null then raise exception 'authentication required'; end if;
 if not exists(select 1 from public.quizzes where id=p_quiz and active) then raise exception 'quiz unavailable'; end if;
 select * into v_session from public.sessions where quiz_id=p_quiz and student_id=auth.uid() and status='in_progress' order by updated_at desc limit 1;
 if not found then insert into public.sessions(quiz_id,student_id) values(p_quiz,auth.uid()) returning * into v_session; end if;
 select id,ordinal,level,prompt,options,feedback into v_question from public.questions where quiz_id=p_quiz and ordinal=v_session.current_ordinal;
 return jsonb_build_object('session_id',v_session.id,'status',v_session.status,'current_ordinal',v_session.current_ordinal,'score',v_session.score,'question',case when v_question.id is null then null else jsonb_build_object('id',v_question.id,'ordinal',v_question.ordinal,'level',v_question.level,'prompt',v_question.prompt,'options',v_question.options,'feedback',v_question.feedback) end);
end $$;
create or replace function public.submit_answer(p_session uuid,p_question uuid,p_selected int) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_s public.sessions; v_q public.questions; v_correct boolean; v_next record;
begin if auth.uid() is null then raise exception 'authentication required'; end if; if p_selected not between 0 and 3 then raise exception 'invalid selection'; end if;
 select * into v_s from public.sessions where id=p_session and student_id=auth.uid() for update; if not found then raise exception 'session not found'; end if;
 -- Make network retries idempotent, including a retry after the final answer completed the session.
 select is_correct into v_correct from public.submissions where session_id=p_session and question_id=p_question;
 if found then return jsonb_build_object('duplicate',true,'is_correct',v_correct,'score',v_s.score,'status',v_s.status,'current_ordinal',v_s.current_ordinal); end if;
 if v_s.status='completed' then raise exception 'session completed'; end if;
 select * into v_q from public.questions where id=p_question and quiz_id=v_s.quiz_id and ordinal=v_s.current_ordinal; if not found then raise exception 'question is not current'; end if;
 v_correct:=p_selected=v_q.answer_index; insert into public.submissions(session_id,question_id,student_id,selected_index,is_correct) values(p_session,p_question,auth.uid(),p_selected,v_correct);
 update public.sessions set score=score+case when v_correct then 1 else 0 end,current_ordinal=current_ordinal+1,status=case when current_ordinal=10 then 'completed' else 'in_progress' end,updated_at=now(),completed_at=case when current_ordinal=10 then now() else null end where id=p_session returning * into v_s;
 select id,ordinal,level,prompt,options,feedback into v_next from public.questions where quiz_id=v_s.quiz_id and ordinal=v_s.current_ordinal;
 return jsonb_build_object('duplicate',false,'is_correct',v_correct,'feedback',v_q.feedback,'score',v_s.score,'status',v_s.status,'current_ordinal',v_s.current_ordinal,'next_question',case when v_next.id is null then null else jsonb_build_object('id',v_next.id,'ordinal',v_next.ordinal,'level',v_next.level,'prompt',v_next.prompt,'options',v_next.options,'feedback',v_next.feedback) end);
end $$;
create or replace function public.teacher_dashboard() returns jsonb language plpgsql security definer set search_path=public as $$
begin if auth.uid() is null or not public.is_teacher() then raise exception 'teacher role required'; end if;
return coalesce((select jsonb_agg(jsonb_build_object('student_id',s.student_id,'display_name',p.display_name,'score',s.score,'status',s.status,'updated_at',s.updated_at) order by s.updated_at desc) from public.sessions s join public.profiles p on p.id=s.student_id),'[]'::jsonb); end $$;
revoke all on function public.start_quiz(uuid) from public; revoke all on function public.submit_answer(uuid,uuid,int) from public; revoke all on function public.teacher_dashboard() from public;
grant execute on function public.start_quiz(uuid) to authenticated; grant execute on function public.submit_answer(uuid,uuid,int) to authenticated; grant execute on function public.teacher_dashboard() to authenticated;

-- Create a student profile at signup. Role elevation remains an admin-only operation.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,display_name,role) values(new.id,coalesce(new.raw_user_meta_data->>'display_name','Murid'),'student') on conflict(id) do nothing; return new; end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
-- Realtime progress/submission streams continue to honor table RLS.
do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='sessions') then alter publication supabase_realtime add table public.sessions; end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='submissions') then alter publication supabase_realtime add table public.submissions; end if;
end $$;
