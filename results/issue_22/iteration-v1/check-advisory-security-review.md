# Security review — issue 22 (package skeleton, contracts, synthetic fixtures)

Attacker-reachable inputs touched: **none** under the threat model's "Where untrusted input enters" list. The new `corpus` and `coa` contracts carry data the book process exports from the user's own book: the booking history and the live chart of accounts, both listed as **trusted**. `corpus.raw_memo` is counterparty text in origin, but this patch only parses it and stores it as-is. It does not render it, log it, stage it or send it anywhere. All 18 building-block modules are stubs that raise `NotImplementedError`.

What I checked, with no finding:

- **Money is exact.** `src/autobook/contracts.py:159-166` (`_cents`) uses `type(value) is not int`, so `12.5`, `1250.0` and `True` are all refused for `amount_cents` and `fraction`. The tests cover these cases (`tests/test_contracts.py:202`, `:209`), plus `"1250"`, `None`, `0` and negatives. The version check at `contracts.py:140-148` refuses `1.0` and `True` in the same way (`tests/test_contracts.py:163`). No float appears anywhere in the contracts or fixtures.
- **Separator-joined account paths.** `_path` (`contracts.py:174-177`) only accepts a non-empty list of non-empty strings, and nothing joins or splits on a separator.
- **Personal data in errors or logs.** `ContractError` messages print field names, types, the contract name and version, `sign`, `provenance` and a bad `post_date` string. They never print `raw_memo` or account path components (`_text` and `_path` report only the type or the index). Nothing in the patch logs anything.
- **The pipeline never imports `gnucash`.** None of the new modules under `src/autobook/pipeline/`, `src/autobook/book/`, `staging.py` or `contracts.py` imports it. All imports are standard library plus `from __future__`.
- **Fixtures are synthetic.** `tests/fixtures/synthetic/corpus_builder.py:17-43` uses invented names (`BEISPIELMARKT`, `MUSTERBAECKEREI`, `NEUHEIM KIOSK`, …), integer cents and no IBANs. `coa.json` holds only the synthetic account tree. The README states the synthetic-only rule.
- **`.gitignore`.** `*.pdf` sits at `.gitignore:42`, inside the "Never commit financial data" block and above the synthetic un-ignore lines (`:54-55`). Real statement PDFs are now ignored, and synthetic PDF fixtures are still allowed.

Two low-priority notes, neither reachable by an attacker (both only matter if the exporter, which is Autobook's own code, writes a broken document). Neither is a NEEDS-HUMAN item:

- Low (informational), `src/autobook/contracts.py:331-335` (`_decode`): `json.loads` keeps the last value of a duplicated key without complaint. I confirmed that a row containing `"amount_cents":100,"amount_cents":200` parses as 200. A strict reader could pass `object_pairs_hook` and refuse duplicate keys. This only matters once a less trusted producer writes a contract (for example `apply-in`, #37), so it fits that cycle better than this one.
- Low (informational), same place: deeply nested input (`"[" * 100000`) raises `RecursionError`, not `ContractError`. Callers that catch only `ContractError` would crash rather than reject the document. The exporter cannot produce such input, so this is out of proportion only in theory.

No finding for this diff.

<!-- pdca:leaf-complete -->
