Use only this Supabase schema.

Tables:
profiles:
- id uuid, pk, references auth.users.id
- first_name text
- last_name text
- role text: admin, trainer
- created_at timestamptz
- updated_at timestamptz

children:
- id uuid
- first_name text
- last_name text
- birth_date date
- age integer
- parent_name text
- parent_phone text
- parent_email text
- notes text
- is_active boolean
- created_at timestamptz
- updated_at timestamptz

scheduled_workshops:
- id uuid
- title text
- workshop_type text
- workshop_date date
- day_of_week text
- start_time time
- end_time time
- trainer_id uuid -> profiles.id
- notes text
- is_active boolean
- created_at timestamptz
- updated_at timestamptz

workshop_children:
- id uuid
- scheduled_workshop_id uuid -> scheduled_workshops.id
- child_id uuid -> children.id
- created_at timestamptz

attendance:
- id uuid
- scheduled_workshop_id uuid -> scheduled_workshops.id
- child_id uuid -> children.id
- status text: present, absent, motivated
- observation text
- marked_by uuid -> profiles.id
- marked_at timestamptz

payments:
- id uuid
- child_id uuid -> children.id
- amount numeric
- currency text
- status text: paid, due, overdue, cancelled
- sessions_count integer
- due_reason text
- paid_at timestamptz
- confirmed_by uuid -> profiles.id
- notes text
- created_at timestamptz
- updated_at timestamptz

lesson_materials:
- id uuid
- title text
- description text
- file_path text
- file_name text
- workshop_type text
- scheduled_workshop_id uuid -> scheduled_workshops.id
- uploaded_by uuid -> profiles.id
- is_active boolean
- created_at timestamptz
- updated_at timestamptz

child_progress:
- id uuid
- child_id uuid -> children.id
- scheduled_workshop_id uuid -> scheduled_workshops.id
- trainer_id uuid -> profiles.id
- title text
- note text
- status text: in_progress, completed, needs_review
- created_at timestamptz
- updated_at timestamptz

notifications:
- id uuid
- title text
- body text
- type text: info, payment, attendance, material, schedule
- recipient_id uuid -> profiles.id
- is_read boolean
- related_child_id uuid -> children.id
- related_workshop_id uuid -> scheduled_workshops.id
- created_at timestamptz

Views:
dashboard_stats:
- total_children
- workshops_today
- pending_payments
- attendance_rate

dashboard_workshops:
- id
- title
- workshop_type
- workshop_date
- day_of_week
- start_time
- end_time
- trainer_id
- trainer_name
- children_count

workshop_details:
- workshop_id
- title
- workshop_type
- workshop_date
- day_of_week
- start_time
- end_time
- trainer_id
- trainer_name
- child_id
- child_first_name
- child_last_name
- parent_name
- parent_phone
- attendance_status
- attendance_observation

Do not use old tables:
- workshops
- groups
- enrollments
- sessions