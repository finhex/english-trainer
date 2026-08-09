# Word-list sources

Reference vocabulary lists used to audit/expand the app's 10k→14k word set.
All are learner/CEFR-graded lists (they include everyday words a *learner* needs,
which pure frequency lists miss — banana, apron, astronaut, badminton…).

| File | Source | Size | Levels | License |
|---|---|---|---|---|
| `efllex.tsv` | EFLLex (Dürlich & François 2018, CENTAL/UCLouvain) — https://cental.uclouvain.be/cefrlex/efllex/ | 15,280 lemmas | A1–C1, per-POS, freq per band | CC BY-NC-SA 4.0 |
| `cefrj-main.csv` | CEFR-J Vocabulary Profile 1.5 (Open Language Profiles) — https://github.com/openlanguageprofiles/olp-en-cefrj | 6,567 | A1–B2 | Open (cite) |
| `cefrj-octanove-c1c2.csv` | Octanove C1/C2 Vocabulary Profile 1.0 (same repo) | ~ | C1–C2 | Open (cite) |
| `missing_content.txt` | Derived: EFLLex ∪ CEFR-J minus our vocab, content words only | 3,760 | — | — |

Base list (already in `data/`): **Maximax67 Words-CEFR-Dataset** (CEFR-J + Google
N-gram) — https://github.com/Maximax67/Words-CEFR-Dataset

Other lists evaluated but not bundled:
- **Oxford 3000/5000** — best grading but Oxford ©, not redistributable.
- **NGSL** (New General Service List, 2,801 core words) — open; its core is already
  covered by EFLLex+CEFR-J.

## How they were used
`add_graded.py` added the 3,760 missing content words (WordNet senses, CEFR level
from CEFR-J then EFLLex, DeepL Russian A1→C1 first). Re-run its DeepL step next
month to finish the ~3.4k definitions left in English when the quota ran out.
