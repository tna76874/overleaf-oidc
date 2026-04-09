# Overleaf with OIDC support

Source: [https://gitlab.informatik.uni-bremen.de/stugen-admins/forks/overleaf-oidc.git](https://gitlab.informatik.uni-bremen.de/stugen-admins/forks/overleaf-oidc.git)

This repository contains patches to run Overleaf CE with support for
OpenID Connect (OIDC) as a login method.

The patches are applied onto the main branch of Overleaf and a Docker
image will be built based on that using the GitLab CI.

The patches and GitLab CI file are heavily inspired by the
fachschaften.org Admin-Team, especially David Mehren, Nicolas Lenz,
and Adrian Kathagen. See their Overleaf-Fork at the
[FSorg-GitLab](https://gitlab.fachschaften.org/tudo-fsinfo/admin/overleaf).

## Configuration

In addition to the base configuration of Overleaf, the following environment
variables have been added:

| Variable                          | Description                                                                                                                        |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `OVERLEAF_ENABLE_LOCAL_LOGIN`     | Set this to `false` to disable the local email/password login (default: `true`)                                                    |
| `OVERLEAF_LOGIN_INFO_TEXT`        | Additional HTML content displayed above the login form and buttons (default: `Welcome to Overleaf! Log in to your account below.`) |
| `OVERLEAF_LOGIN_OIDC_BUTTON`      | Label of the OIDC login button (default: `Log in with SSO`)                                                                        |
| `OVERLEAF_OIDC_ISSUER`            | Issuer URL of the OIDC provider (when unset, OIDC login is disabled)                                                               |
| `OVERLEAF_OIDC_AUTHORIZATION_URL` | Authorization URL to start the OIDC flow                                                                                           |
| `OVERLEAF_OIDC_TOKEN_URL`         | Token URL for exchanging the auth code for an access token                                                                         |
| `OVERLEAF_OIDC_USERINFO_URL`      | URL of the endpoint containing user information in OIDC claims standard format                                                     |
| `OVERLEAF_OIDC_CALLBACK_URL`      | URL for the redirect callback from the auth provider, should be base domain plus `/login/oidc/callback`                            |
| `OVERLEAF_OIDC_SCOPE`             | The scopes to request at the auth provider (default: `openid profile email`)                                                       |
| `OVERLEAF_OIDC_CLIENT_ID`         | The client id registered at the OIDC provider                                                                                      |
| `OVERLEAF_OIDC_CLIENT_SECRET`     | The client secret for the registration at the OIDC provider                                                                        |
| `OVERLEAF_OIDC_MATCHING`          | Which identifier to use for lookups in the database, one of `id` or `username` (default: `id`)                                     |
| `OVERLEAF_OIDC_LOGIN_IN_NAVBAR`   | Whether to show a distinct SSO login button in the navbar (default: `false`)                                                       |
| `OVERLEAF_ENABLE_SHELL_ESCAPE`    | Whether to add the `-shell-escape` flag to the LaTeX compiler, should only be done with sandboxed compiles                         |
