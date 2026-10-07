-- Run once in a NEW Supabase project's SQL Editor.
BEGIN;
CREATE SCHEMA IF NOT EXISTS desk_private;
CREATE TABLE desk_private.staff(user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,email text NOT NULL UNIQUE,role text NOT NULL CHECK(role IN ('reporter','closer','admin')));
CREATE TABLE desk_private.machines(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),department text NOT NULL CHECK(department IN ('Milling department','Press','Glazing lines','Kiln','Polishing & Squaring','Sorting & Packing')),name text NOT NULL CHECK(length(name) BETWEEN 1 AND 100),key text NOT NULL UNIQUE);
CREATE TABLE desk_private.reasons(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),category text NOT NULL CHECK(category IN ('Electrical','Mechanical','Production','Quality')),description text NOT NULL CHECK(length(description) BETWEEN 1 AND 1000),key text NOT NULL UNIQUE);
CREATE TABLE desk_private.breakdowns(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),machine_id uuid NOT NULL REFERENCES desk_private.machines(id),category text NOT NULL CHECK(category IN ('Electrical','Mechanical','Production','Quality')),reason text NOT NULL CHECK(length(reason) BETWEEN 1 AND 1000),start bigint NOT NULL CHECK(start>0),"end" bigint CHECK("end">=start),reported_by text NOT NULL,closed_by text,resolution text,created_at bigint NOT NULL);
CREATE UNIQUE INDEX one_active_per_machine ON desk_private.breakdowns(machine_id) WHERE "end" IS NULL;
CREATE INDEX breakdowns_start ON desk_private.breakdowns(start DESC);
ALTER TABLE desk_private.staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE desk_private.machines ENABLE ROW LEVEL SECURITY;
ALTER TABLE desk_private.reasons ENABLE ROW LEVEL SECURITY;
ALTER TABLE desk_private.breakdowns ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON SCHEMA desk_private FROM PUBLIC,anon,authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA desk_private FROM PUBLIC,anon,authenticated;
CREATE FUNCTION desk_private.require_role() RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE user_role text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Please sign in.'; END IF;
 SELECT role INTO user_role FROM desk_private.staff WHERE user_id=auth.uid();
 IF user_role IS NULL THEN RAISE EXCEPTION 'Your account has not been added to this workspace. Ask the administrator for access.'; END IF;
 RETURN user_role;
END; $$;
REVOKE ALL ON FUNCTION desk_private.require_role() FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.desk_data() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE user_role text; user_email text; result jsonb;
BEGIN
 user_role:=desk_private.require_role();
 SELECT email INTO user_email FROM desk_private.staff WHERE user_id=auth.uid();
 SELECT jsonb_build_object(
 'machines',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',id,'department',department,'name',name,'key',key) ORDER BY department,name) FROM desk_private.machines),'[]'::jsonb),
 'reasons',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',id,'category',category,'description',description,'key',key) ORDER BY description) FROM desk_private.reasons),'[]'::jsonb),
 'breakdowns',COALESCE((SELECT jsonb_agg(jsonb_build_object('id',id,'machineId',machine_id,'category',category,'reason',reason,'start',start,'end',"end",'reportedBy',reported_by,'closedBy',closed_by,'resolution',resolution,'createdAt',created_at) ORDER BY start DESC) FROM desk_private.breakdowns),'[]'::jsonb),
 'staff',CASE WHEN user_role='admin' THEN COALESCE((SELECT jsonb_agg(jsonb_build_object('email',email,'role',role) ORDER BY email) FROM desk_private.staff),'[]'::jsonb) ELSE '[]'::jsonb END,
 'user',jsonb_build_object('email',user_email,'name',split_part(user_email,'@',1),'role',user_role),
 'serverTime',floor(extract(epoch FROM clock_timestamp())*1000)::bigint
 ) INTO result;
 RETURN result;
END; $$;
REVOKE ALL ON FUNCTION public.desk_data() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.desk_data() TO authenticated;
CREATE FUNCTION public.desk_mutate(payload jsonb) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 user_role text; user_email text; operation text; dept text; machine_name text; cat text; why text; started bigint; ended bigint; now_ms bigint;
 machine_key text; mid uuid; bid uuid; existing desk_private.breakdowns%ROWTYPE; target_email text; target_id uuid; target_role text;
BEGIN
 user_role:=desk_private.require_role();
 SELECT email INTO user_email FROM desk_private.staff WHERE user_id=auth.uid();
 operation:=payload->>'action';now_ms:=floor(extract(epoch FROM clock_timestamp())*1000)::bigint;
 IF operation='report' THEN
  dept:=payload->>'department';machine_name:=regexp_replace(trim(payload->>'machine'),'\s+',' ','g');cat:=payload->>'category';why:=trim(payload->>'reason');started:=(payload->>'start')::bigint;
  IF dept IS NULL OR dept NOT IN ('Milling department','Press','Glazing lines','Kiln','Polishing & Squaring','Sorting & Packing') OR cat IS NULL OR cat NOT IN ('Electrical','Mechanical','Production','Quality') OR machine_name IS NULL OR length(machine_name) NOT BETWEEN 1 AND 100 OR why IS NULL OR length(why) NOT BETWEEN 1 AND 1000 OR started IS NULL OR started<=0 OR started>now_ms THEN RAISE EXCEPTION 'Enter a department, machine, category, reason and a start time that is not in the future.'; END IF;
  machine_key:=dept||'|'||lower(machine_name);
  INSERT INTO desk_private.machines(department,name,key) VALUES(dept,machine_name,machine_key) ON CONFLICT(key) DO NOTHING;
  SELECT id INTO mid FROM desk_private.machines WHERE key=machine_key FOR UPDATE;
  IF EXISTS(SELECT 1 FROM desk_private.breakdowns WHERE machine_id=mid AND ("end" IS NULL OR "end">started)) THEN RAISE EXCEPTION 'This machine already has an ongoing breakdown or a recorded breakdown overlapping this start time.'; END IF;
  INSERT INTO desk_private.breakdowns(machine_id,category,reason,start,reported_by,created_at) VALUES(mid,cat,why,started,user_email,now_ms);
  INSERT INTO desk_private.reasons(category,description,key) VALUES(cat,why,cat||'|'||lower(regexp_replace(why,'\s+',' ','g'))) ON CONFLICT(key) DO NOTHING;
 ELSIF operation='close' THEN
  IF user_role NOT IN ('admin','closer') THEN RAISE EXCEPTION 'Only authorized staff can close a breakdown.'; END IF;
  bid:=(payload->>'id')::uuid;ended:=(payload->>'end')::bigint;
  SELECT * INTO existing FROM desk_private.breakdowns WHERE id=bid FOR UPDATE;
  IF NOT FOUND OR existing."end" IS NOT NULL THEN RAISE EXCEPTION 'This breakdown has already been closed or does not exist.'; END IF;
  IF ended IS NULL OR ended<existing.start OR ended>now_ms THEN RAISE EXCEPTION 'End time must be between the start time and the current time.'; END IF;
  IF length(COALESCE(payload->>'resolution',''))>1000 THEN RAISE EXCEPTION 'Resolution must be under 1,000 characters.'; END IF;
  UPDATE desk_private.breakdowns SET "end"=ended,closed_by=user_email,resolution=trim(COALESCE(payload->>'resolution','')) WHERE id=bid;
 ELSIF operation='staff' THEN
  IF user_role<>'admin' THEN RAISE EXCEPTION 'Only administrators can change staff access.'; END IF;
  PERFORM pg_advisory_xact_lock(726451);
  target_email:=lower(trim(payload->>'email'));
  IF target_email IS NULL OR target_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]+$' THEN RAISE EXCEPTION 'Enter a valid email address.'; END IF;
  SELECT id INTO target_id FROM auth.users WHERE lower(email)=target_email;
  IF target_id IS NULL THEN RAISE EXCEPTION 'Create this account in Supabase Authentication first, then assign access here.'; END IF;
  SELECT role INTO target_role FROM desk_private.staff WHERE user_id=target_id;
  IF target_id=auth.uid() THEN RAISE EXCEPTION 'Use another administrator account to change your own role.'; END IF;
  IF target_role='admin' AND ((payload->>'remove')::boolean IS TRUE OR payload->>'role'<>'admin') AND (SELECT count(*) FROM desk_private.staff WHERE role='admin')<=1 THEN RAISE EXCEPTION 'At least one administrator must remain.'; END IF;
  IF (payload->>'remove')::boolean IS TRUE THEN DELETE FROM desk_private.staff WHERE user_id=target_id;
  ELSE
   target_role:=payload->>'role';
   IF target_role IS NULL OR target_role NOT IN ('reporter','closer','admin') THEN RAISE EXCEPTION 'Invalid staff role.'; END IF;
   INSERT INTO desk_private.staff(user_id,email,role) VALUES(target_id,target_email,target_role) ON CONFLICT(user_id) DO UPDATE SET email=EXCLUDED.email,role=EXCLUDED.role;
  END IF;
 ELSE RAISE EXCEPTION 'Unknown action.';
 END IF;
 RETURN jsonb_build_object('ok',true);
EXCEPTION WHEN unique_violation THEN RAISE EXCEPTION 'This machine already has an ongoing breakdown. Refresh the status tab.';
END; $$;
REVOKE ALL ON FUNCTION public.desk_mutate(jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.desk_mutate(jsonb) TO authenticated;
COMMIT;
-- Create your first account in Authentication > Users > Add user.
-- Then run the admin INSERT shown in START-HERE.md separately.
