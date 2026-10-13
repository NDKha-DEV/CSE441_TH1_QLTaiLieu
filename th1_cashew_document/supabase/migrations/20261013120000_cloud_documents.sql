create table public.users (
  firebase_uid text primary key,
  email text,
  display_name text,
  created_at timestamptz not null default now()
);

create table public.documents (
  id uuid primary key,
  owner_uid text not null references public.users(firebase_uid) on delete cascade,
  title text not null,
  description text,
  subject text not null,
  document_type text not null,
  file_name text not null,
  storage_path text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.permissions (
  document_id uuid not null references public.documents(id) on delete cascade,
  user_uid text not null references public.users(firebase_uid) on delete cascade,
  role text not null check (role in ('viewer', 'editor')),
  granted_by text not null references public.users(firebase_uid),
  created_at timestamptz not null default now(),
  primary key (document_id, user_uid)
);

create index permissions_user_uid_idx on public.permissions(user_uid);

create or replace function public.prevent_document_identity_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.owner_uid <> old.owner_uid or new.storage_path <> old.storage_path then
    raise exception 'Document owner and storage path cannot be changed';
  end if;
  return new;
end;
$$;

drop trigger if exists documents_identity_immutable on public.documents;
create trigger documents_identity_immutable
before update on public.documents
for each row execute function public.prevent_document_identity_change();

create or replace function public.is_document_owner(_document_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.documents d
    where d.id = _document_id
      and d.owner_uid = (select auth.jwt() ->> 'sub')
  );
$$;

create or replace function public.can_access_document(_document_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_document_owner(_document_id)
    or exists (
      select 1
      from public.permissions p
      where p.document_id = _document_id
        and p.user_uid = (select auth.jwt() ->> 'sub')
        and p.role in ('viewer', 'editor')
    );
$$;

create or replace function public.can_edit_document(_document_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_document_owner(_document_id)
    or exists (
      select 1
      from public.permissions p
      where p.document_id = _document_id
        and p.user_uid = (select auth.jwt() ->> 'sub')
        and p.role = 'editor'
    );
$$;

create or replace function public.can_read_document_object(_object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.documents d
    where d.storage_path = _object_name
      and public.can_access_document(d.id)
  );
$$;

create or replace function public.can_write_document_object(_object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.documents d
    where d.storage_path = _object_name
      and public.can_edit_document(d.id)
  );
$$;

create or replace function public.can_delete_document_object(_object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.documents d
    where d.storage_path = _object_name
      and public.is_document_owner(d.id)
  );
$$;

revoke all on function public.is_document_owner(uuid) from public, anon;
revoke all on function public.can_access_document(uuid) from public, anon;
revoke all on function public.can_edit_document(uuid) from public, anon;
revoke all on function public.can_read_document_object(text) from public, anon;
revoke all on function public.can_write_document_object(text) from public, anon;
revoke all on function public.can_delete_document_object(text) from public, anon;
grant execute on function public.is_document_owner(uuid) to authenticated;
grant execute on function public.can_access_document(uuid) to authenticated;
grant execute on function public.can_edit_document(uuid) to authenticated;
grant execute on function public.can_read_document_object(text) to authenticated;
grant execute on function public.can_write_document_object(text) to authenticated;
grant execute on function public.can_delete_document_object(text) to authenticated;

revoke all on function public.prevent_document_identity_change() from public, anon;

alter table public.users enable row level security;
alter table public.documents enable row level security;
alter table public.permissions enable row level security;

grant select, insert, update on public.users to authenticated;
grant select, insert, update, delete on public.documents to authenticated;
grant select, insert, update, delete on public.permissions to authenticated;

drop policy if exists users_select_self on public.users;
drop policy if exists users_insert_self on public.users;
drop policy if exists users_update_self on public.users;
drop policy if exists documents_select_accessible on public.documents;
drop policy if exists documents_insert_owner on public.documents;
drop policy if exists documents_update_editor on public.documents;
drop policy if exists documents_delete_owner on public.documents;
drop policy if exists permissions_select_owner_or_recipient on public.permissions;
drop policy if exists permissions_insert_owner on public.permissions;
drop policy if exists permissions_update_owner on public.permissions;
drop policy if exists permissions_delete_owner on public.permissions;

create policy users_select_self on public.users
for select to authenticated
using (firebase_uid = (select auth.jwt() ->> 'sub'));

create policy users_insert_self on public.users
for insert to authenticated
with check (firebase_uid = (select auth.jwt() ->> 'sub'));

create policy users_update_self on public.users
for update to authenticated
using (firebase_uid = (select auth.jwt() ->> 'sub'))
with check (firebase_uid = (select auth.jwt() ->> 'sub'));

create policy documents_select_accessible on public.documents
for select to authenticated
using (public.can_access_document(id));

create policy documents_insert_owner on public.documents
for insert to authenticated
with check (owner_uid = (select auth.jwt() ->> 'sub'));

create policy documents_update_editor on public.documents
for update to authenticated
using (public.can_edit_document(id))
with check (public.can_edit_document(id));

create policy documents_delete_owner on public.documents
for delete to authenticated
using (public.is_document_owner(id));

create policy permissions_select_owner_or_recipient on public.permissions
for select to authenticated
using (
  user_uid = (select auth.jwt() ->> 'sub')
  or public.is_document_owner(document_id)
);

create policy permissions_insert_owner on public.permissions
for insert to authenticated
with check (
  public.is_document_owner(document_id)
  and granted_by = (select auth.jwt() ->> 'sub')
);

create policy permissions_update_owner on public.permissions
for update to authenticated
using (public.is_document_owner(document_id))
with check (
  public.is_document_owner(document_id)
  and granted_by = (select auth.jwt() ->> 'sub')
);

create policy permissions_delete_owner on public.permissions
for delete to authenticated
using (public.is_document_owner(document_id));

insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do update set public = false;

drop policy if exists documents_storage_select on storage.objects;
drop policy if exists documents_storage_insert on storage.objects;
drop policy if exists documents_storage_update on storage.objects;
drop policy if exists documents_storage_delete on storage.objects;

create policy documents_storage_select on storage.objects
for select to authenticated
using (
  bucket_id = 'documents'
  and public.can_read_document_object(name)
);

create policy documents_storage_insert on storage.objects
for insert to authenticated
with check (
  bucket_id = 'documents'
  and public.can_write_document_object(name)
);

create policy documents_storage_update on storage.objects
for update to authenticated
using (
  bucket_id = 'documents'
  and public.can_write_document_object(name)
)
with check (
  bucket_id = 'documents'
  and public.can_write_document_object(name)
);

create policy documents_storage_delete on storage.objects
for delete to authenticated
using (
  bucket_id = 'documents'
  and public.can_delete_document_object(name)
);
