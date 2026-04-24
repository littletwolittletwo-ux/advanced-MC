-- Run this in Supabase Dashboard > SQL Editor
create table if not exists builder_tasks (
  task_id uuid primary key,
  received_from text not null default 'sunny',
  brief text not null,
  pr_url text,
  status text not null check (status in ('working','pr-open','merged','escalated','failed','done-but-unlogged')),
  spawned_sessions text[],
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists builder_tasks_status_idx on builder_tasks(status);
create index if not exists builder_tasks_started_at_idx on builder_tasks(started_at desc);
