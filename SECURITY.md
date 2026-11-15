# Security

If you find a security or privacy issue in OpenSkateMap, please tell us privately first.

## Reporting

- **GitHub:** the repository's **Security** tab → **Report a vulnerability** (a private advisory only maintainers see).
- **Email:** hey@openskatemap.app, with "Security" in the subject.

Please don't open a public issue, pull request or discussion about it. Include what you found, how to reproduce it
and what someone could do with it. We'll reply within a week, keep you posted while we fix it, and credit you when
it's out, unless you'd rather we didn't.

## Scope

- The iOS app, the latest version on the App Store or TestFlight.
- The API at `api.openskatemap.app`, the website at `openskatemap.app` and photos at `images.openskatemap.app`
  (their code is in [OpenSkateMap/cloud](https://github.com/OpenSkateMap/cloud)).

Out of scope: denial of service and load testing, spam, social engineering, and issues in services we use (Apple,
Cloudflare, PlanetScale, PostHog, RevenueCat) that aren't caused by how we use them.

## Testing

Use your own account. Don't read, change or delete anyone else's data, don't run automated scanners against the
live servers, and stop as soon as you've shown the issue. The backend runs locally with sample data (see its README),
which is the best place to dig.
