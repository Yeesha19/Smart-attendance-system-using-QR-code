-- 004_seed_demo_data.sql
-- Comprehensive demo data for QR Attendance
-- - Replaces STAT 321 with CIT415, CIT410, CIT484
-- - Creates 24 new students + keeps existing student (25 total)
-- - Enrolls all students in all courses
-- - Generates 10 sessions per course with realistic attendance records

-- Actual lecturer UUID (from auth.users)
-- Dr. Smith = 5d4befba-0a43-4c89-a4e8-235072ff554f

-- Step 1: Clean slate — remove ALL old sessions, attendance, enrollments, courses
delete from public.attendance;
delete from public.sessions;
delete from public.enrollments;
delete from public.courses;

-- Step 2: Create new courses
insert into public.courses (id, name, code, lecturer_id) values
  ('c0000000-0000-0000-0000-000000000002'::uuid, 'Introduction to E-commerce',           'CIT415', '5d4befba-0a43-4c89-a4e8-235072ff554f'::uuid),
  ('c0000000-0000-0000-0000-000000000003'::uuid, 'Introduction to Cyber Security',        'CIT410', '5d4befba-0a43-4c89-a4e8-235072ff554f'::uuid),
  ('c0000000-0000-0000-0000-000000000004'::uuid, 'Website Design and Programming',        'CIT484', '5d4befba-0a43-4c89-a4e8-235072ff554f'::uuid),
  ('c0000000-0000-0000-0000-000000000005'::uuid, 'Introduction to Expert Systems',        'CIT474', '5d4befba-0a43-4c89-a4e8-235072ff554f'::uuid);

-- Step 3: Create a temporary table with student data
create temp table new_students (
  row_id     serial primary key,
  name       text not null,
  email      text not null,
  matric_no  text not null
);

insert into new_students (name, email, matric_no) values
  ('Adebayo Ogunlesi',   'adebayo.ogunlesi@university.edu',  'NOU223094977'),
  ('Chioma Obi',         'chioma.obi@university.edu',        'NOU223094978'),
  ('Emeka Nwosu',        'emeka.nwosu@university.edu',       'NOU223094979'),
  ('Folake Adegoke',     'folake.adegoke@university.edu',    'NOU223094980'),
  ('Chidi Okonkwo',      'chidi.okonkwo@university.edu',     'NOU223094981'),
  ('Zainab Bello',       'zainab.bello@university.edu',      'NOU223094982'),
  ('Olusegun Adebayo',   'olusegun.adebayo@university.edu',  'NOU223094983'),
  ('Ngozi Eze',          'ngozi.eze@university.edu',         'NOU223094984'),
  ('Tunde Balogun',      'tunde.balogun@university.edu',     'NOU223094985'),
  ('Yetunde Alabi',      'yetunde.alabi@university.edu',     'NOU223094986'),
  ('Ibrahim Musa',       'ibrahim.musa@university.edu',      'NOU223094987'),
  ('Kemi Adepoju',       'kemi.adepoju@university.edu',      'NOU223094988'),
  ('Chibueze Nwachukwu', 'chibueze.nwachukwu@university.edu','NOU223094989'),
  ('Ronke Ojo',          'ronke.ojo@university.edu',         'NOU223094990'),
  ('Segun Ogunleye',     'segun.ogunleye@university.edu',    'NOU223094991'),
  ('Temitope Adeyemi',   'temitope.adeyemi@university.edu',  'NOU223094992'),
  ('Uche Nwosu',         'uche.nwosu@university.edu',        'NOU223094993'),
  ('Victoria Okafor',    'victoria.okafor@university.edu',   'NOU223094994'),
  ('Wale Adeleke',       'wale.adeleke@university.edu',      'NOU223094995'),
  ('Yemi Ogunbiyi',      'yemi.ogunbiyi@university.edu',     'NOU223094996'),
  ('Adaeze Nwankwo',     'adaeze.nwankwo@university.edu',    'NOU223094997'),
  ('Babatunde Ogun',     'babatunde.ogun@university.edu',    'NOU223094998'),
  ('Chinwe Okoro',       'chinwe.okoro@university.edu',      'NOU223094999'),
  ('Dayo Adekunle',      'dayo.adekunle@university.edu',     'NOU223095000');

-- Step 4: Create auth.users and auth.identities for each new student,
-- then fix the auto-created public.users profile
do $$
declare
  r record;
  new_id uuid;
begin
  for r in select * from new_students order by row_id loop
    new_id := gen_random_uuid();

    -- auth.users
    insert into auth.users (id, instance_id, email, encrypted_password,
      email_confirmed_at, confirmation_sent_at, confirmation_token,
      recovery_token, email_change, email_change_token_new, email_change_token_current,
      reauthentication_token, phone_change_token,
      created_at, updated_at,
      raw_app_meta_data, raw_user_meta_data, aud, role,
      is_sso_user, is_anonymous)
    values (
      new_id,
      '00000000-0000-0000-0000-000000000000',
      r.email,
      crypt('password123', gen_salt('bf', 10)),
      now(), now(), encode(gen_random_bytes(28), 'hex'),
      '', '', '', '',
      '', '',
      now(), now(),
      '{"provider":"email","providers":["email"],"app_role":"student"}',
      jsonb_build_object(
        'sub', new_id,
        'email', r.email,
        'email_verified', false,
        'phone_verified', false
      ),
      'authenticated', 'authenticated',
      false, false
    );

    -- auth.identities
    insert into auth.identities (provider_id, user_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at)
    values (
      new_id, new_id,
      jsonb_build_object(
        'sub', new_id,
        'email', r.email,
        'email_verified', false,
        'phone_verified', false
      ),
      'email', now(), now(), now()
    );

    -- Fix the auto-created public.users profile
    update public.users set
      role = 'student',
      name = r.name,
      email = null,
      matric_no = r.matric_no
    where id = new_id;
  end loop;
end;
$$;

drop table new_students;

-- Step 5: Collect all student IDs
create temp table all_students as
  select id from public.users where role = 'student' order by created_at;

-- Step 6: Enroll every student in every course
insert into public.enrollments (student_id, course_id)
select s.id, c.id
from all_students s
cross join (select id from public.courses where lecturer_id = '5d4befba-0a43-4c89-a4e8-235072ff554f'::uuid) c
on conflict (student_id, course_id) do nothing;

-- Step 7: Sessions and attendance
do $$
declare
  c record;
  sd date[];
  d  date;
  sid uuid;
  s_id uuid;
  att_pct float;
  idx int := 0;
begin
  for c in select id, code from public.courses
           where lecturer_id = '5d4befba-0a43-4c89-a4e8-235072ff554f'::uuid
           order by code
  loop
    -- Generate 10 weekdays going back ~6 weeks with varied spacing
    sd := '{}';
    d := current_date - interval '6 weeks';

    while array_length(sd, 1) is null or array_length(sd, 1) < 10 loop
      if extract(dow from d) not in (0, 6) then
        sd := sd || d;
      end if;
      d := d + interval '1 day' * (3 + floor(random() * 3)::int);
    end loop;

    -- Create sessions + attendance
    foreach d in array sd loop
      idx := idx + 1;
      s_id := gen_random_uuid();

      insert into public.sessions (id, course_id, date, qr_token, expires_at)
      values (
        s_id, c.id, d,
        gen_random_uuid(),
        d::timestamptz + interval '3 hours'
      );

      -- Attendance: each student attends with varying probability
      -- Student-level attendance tendencies:
      --   ~20% are "often absent" (55-65%)
      --   ~30% are "moderate" (65-78%)
      --   ~35% are "good" (78-88%)
      --   ~15% are "excellent" (88-95%)
      for sid in select id from all_students loop
        -- Deterministic-ish: assign a "student attendance factor"
        -- by hashing the student id mod 100
        att_pct := case
          when (abs(hashtext(sid::text || c.id::text)) % 100) between 0 and 19
            then 0.55 + random() * 0.10
          when (abs(hashtext(sid::text || c.id::text)) % 100) between 20 and 49
            then 0.65 + random() * 0.13
          when (abs(hashtext(sid::text || c.id::text)) % 100) between 50 and 84
            then 0.78 + random() * 0.10
          else 0.88 + random() * 0.07
        end;

        if random() < att_pct then
          insert into public.attendance (session_id, student_id, scanned_at)
          values (
            s_id, sid,
            d::timestamptz + interval '10 minutes' + (random() * interval '15 minutes')
          )
          on conflict (session_id, student_id) do nothing;
        end if;
      end loop;
    end loop;
  end loop;
end;
$$;

drop table all_students;
