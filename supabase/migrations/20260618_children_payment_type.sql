-- Add `payment_type` to `children`.
--
-- Supports non-paying children ("Participare gratuită"): family friends,
-- scholarships, etc. Free children remain fully visible in attendance,
-- workshops, progress and reports, but are excluded from the payment
-- workflow (due / overdue cycles, payment notifications, financial
-- summaries).
--
-- Migration policy:
--   * default value 'paid' is applied to every existing row by Postgres
--     when ADD COLUMN ... NOT NULL DEFAULT runs in one statement, so no
--     data loss occurs.
--   * The CHECK constraint pins the column to a closed set ('paid', 'free')
--     so unknown values cannot reach storage.

ALTER TABLE public.children
  ADD COLUMN IF NOT EXISTS payment_type text NOT NULL DEFAULT 'paid';

ALTER TABLE public.children
  DROP CONSTRAINT IF EXISTS children_payment_type_check;

ALTER TABLE public.children
  ADD CONSTRAINT children_payment_type_check
  CHECK (payment_type IN ('paid', 'free'));

-- Index used by payment-due / financial queries that filter free children
-- out at the DB layer.
CREATE INDEX IF NOT EXISTS idx_children_payment_type
  ON public.children(payment_type);

COMMENT ON COLUMN public.children.payment_type IS
  '''paid'' (regular paying participant) or ''free'' (sponsored / family friend / scholarship). '
  'Free children remain visible in attendance, workshops, progress and reports but are '
  'excluded from the payment workflow (due/overdue cycles, payment notifications, '
  'financial summaries).';

-- ─── Defensive trigger: drop payment-type notifications for free children ────
--
-- The notifications table is populated by various server-side jobs and
-- triggers. To guarantee no payment reminders ever reach a parent (or staff
-- member) for a free participant, we silently skip the INSERT when the
-- target child is marked as 'free'.

CREATE OR REPLACE FUNCTION public.tg_skip_payment_notification_for_free_child()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  _is_free boolean;
BEGIN
  IF NEW.related_child_id IS NULL THEN RETURN NEW; END IF;
  IF COALESCE(NEW.type, '') <> 'payment' THEN RETURN NEW; END IF;
  SELECT (payment_type = 'free') INTO _is_free
    FROM public.children
    WHERE id = NEW.related_child_id;
  IF _is_free IS TRUE THEN
    RETURN NULL;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_notifications_skip_free_payments
  ON public.notifications;

CREATE TRIGGER trg_notifications_skip_free_payments
  BEFORE INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_skip_payment_notification_for_free_child();

-- ─── Defensive trigger: drop payment_cycle INSERT for free children ──────────
--
-- The "after-4-presents" cycle generation logic runs server-side (likely a
-- trigger or RPC on attendance writes). For free participants we want NO
-- payment_cycles rows to ever be created so that:
--   * attendance.payment_cycle_id stays NULL forever for those children,
--   * the "current status" UI can compute a 4-attendance block client-side
--     by walking the unarchived attendance history,
--   * free children never surface in payments_due, financial summaries,
--     or any payment-related notification path.
--
-- A BEFORE INSERT trigger returning NULL silently skips the row without
-- raising — the calling trigger's `RETURNING id INTO ...` will receive
-- NULL and any subsequent `UPDATE attendance SET payment_cycle_id = ...`
-- becomes a no-op, leaving the rows in the "open block" state.

CREATE OR REPLACE FUNCTION public.tg_skip_payment_cycle_for_free_child()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  _is_free boolean;
BEGIN
  IF NEW.child_id IS NULL THEN RETURN NEW; END IF;
  SELECT (payment_type = 'free') INTO _is_free
    FROM public.children
    WHERE id = NEW.child_id;
  IF _is_free IS TRUE THEN
    RETURN NULL;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_payment_cycles_skip_free
  ON public.payment_cycles;

CREATE TRIGGER trg_payment_cycles_skip_free
  BEFORE INSERT ON public.payment_cycles
  FOR EACH ROW
  EXECUTE FUNCTION public.tg_skip_payment_cycle_for_free_child();
