# mm-adversarial

Adversarial security review — think like an attacker trying to break the system. Finds exploit vectors, logic abuse, privilege escalation, and insider threats.

## Instructions
Adversarial code review. Think like an attacker trying to break this system.

This is not a standard review. You are looking for ways to make the system do things it was not designed to do.

Read the changed code. For each component, ask:

**As a malicious user:**
- What inputs can I craft to get unexpected behavior?
- Can I access data that belongs to another user?
- Can I bypass the intended flow (skip payment, skip auth, skip validation)?
- Can I escalate my own privileges?
- What happens if I replay a request? Send it 1000 times?
- Can I trigger a state that breaks the system for other users?

**As an insider threat:**
- What can a legitimate low-privilege user do that they shouldn't?
- What could an admin do that would be hard to detect?
- Are there audit log gaps that would hide malicious activity?

**As an external attacker:**
- What is exposed without authentication?
- What information leaks from error messages, headers, timing differences?
- Are there any endpoints that accept callbacks or redirects (SSRF, open redirect)?
- What third-party integrations could be abused if compromised?

**As a logic abuser:**
- What race conditions exist? (e.g., check-then-act patterns)
- What happens if I send requests out of order?
- Are numeric operations safe from overflow/underflow?
- Can I abuse pagination, sorting, or filter parameters?

For each finding:
```
🔴 EXPLOIT: [what I can do]
   Vector: [how — specific endpoint/input/sequence]
   Impact: [what data or capability I gain]
   Fix: [specific code change]
```

Then list assumptions you made that couldn't be verified — things that could be vulnerabilities depending on code you didn't see.

End with a threat summary: "The highest-risk attack vector is [X] because [Y]."
