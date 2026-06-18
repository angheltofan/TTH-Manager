-- One-shot, idempotent repair of UTF-8-then-Latin1 mojibake in
-- `public.notifications`. If any historical row was written while a
-- producer mis-decoded UTF-8 as Windows-1252 (or Latin-1) the Romanian
-- diacritics end up as predictable two-character sequences — most
-- commonly `ă` rendered as `Ä` + `ƒ`. This migration walks each
-- corruption pair in `title` and `body` and undoes it.
--
-- Re-running is safe: clean strings do not match any of the source
-- sequences and stay untouched, so this migration is idempotent.

UPDATE public.notifications
SET
  title = COALESCE(title, ''),
  body = COALESCE(body, '')
WHERE title IS NULL OR body IS NULL;

UPDATE public.notifications
SET
  title = replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(
    title,
    'Äƒ', 'ă'),
    'Ä‚', 'Ă'),
    'Ã¢', 'â'),
    'Ã‚', 'Â'),
    'Ã®', 'î'),
    'ÃŽ', 'Î'),
    'È™', 'ș'),
    'È˜', 'Ș'),
    'È›', 'ț'),
    'Èš', 'Ț'),
    'ÅŸ', 'ş'),
    'Å£', 'ţ'),
  body = replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(
    body,
    'Äƒ', 'ă'),
    'Ä‚', 'Ă'),
    'Ã¢', 'â'),
    'Ã‚', 'Â'),
    'Ã®', 'î'),
    'ÃŽ', 'Î'),
    'È™', 'ș'),
    'È˜', 'Ș'),
    'È›', 'ț'),
    'Èš', 'Ț'),
    'ÅŸ', 'ş'),
    'Å£', 'ţ')
WHERE
  title ~ '(Äƒ|Ä‚|Ã¢|Ã‚|Ã®|ÃŽ|È™|È˜|È›|Èš|ÅŸ|Å£)'
  OR body ~ '(Äƒ|Ä‚|Ã¢|Ã‚|Ã®|ÃŽ|È™|È˜|È›|Èš|ÅŸ|Å£)';
