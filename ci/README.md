# Mobile CI workflow

`flutter_ci.yml` is the GitHub Actions workflow for the mobile app (analyze,
tests with coverage, and test-plan checks). It lives here because the account
that pushed it could not write to `.github/workflows/`.

To turn it on, move it into place:

    git mv ci/flutter_ci.yml .github/workflows/flutter_ci.yml

The test plan is in `testing/test_plan.yaml`; UI flows are in `.maestro/`.
