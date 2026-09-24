---
name: chronicle-protocol
description: 'Write project checkpoints when the user says "Chronicle", "Chronicle this", "let us Chronicle", or "time to Chronicle" as a request to save project state. Also use when resuming a project from a Chronicle checkpoint. Distinct from Copilot session-history analysis; quoting or editing this protocol is not a checkpoint request.'
user-invocable: false
---

# The Chronicle Protocol

A platform-agnostic checkpoint system for long-running projects. Use the current conversation and verified project artifacts to preserve enough state for a fresh session to continue.

## Trigger

Treat **"Chronicle"** as a checkpoint request when the user uses it as an instruction, including "Chronicle this", "let's Chronicle", and "time to Chronicle". Ordinary conversation, quoted text, and requests to edit this protocol are not triggers. Create a checkpoint only on that explicit request; resuming reads an existing checkpoint.

The plain-language trigger requires these instructions to be available to the assistant. This skill does not register a separate command or a session-start hook. For a check at every new session, the host's always-loaded project instructions must direct the assistant to this protocol; installing an on-demand skill alone does not guarantee that behavior.

## Write a checkpoint

1. Inspect the file-write capabilities available in this session: file tools, shell access, or writable project storage. Choose the project's existing checkpoint location; otherwise use a `chronicles/` directory at the project root when working in a repository, or the platform's working-file location.
2. Establish the project name and current date from available context. Ask if either is unclear. Use a filesystem-safe project name and the filename `chronicle_<project-name>_<YYYY-MM-DD>.md`. Check whether that file already exists; ask before replacing it or choosing an alternative filename.
3. Build the checkpoint using the seven sections below, in order. Record only supported facts, distinguish completed work from proposed work, and mark unresolved information as unclear. Ask when unsure whether something belongs in the checkpoint.
4. If a write tool is available, attempt the write and verify success from the tool result or a read-back. Uncertainty about capability is a reason to inspect and try an available tool, not to skip the checkpoint.
5. If writing is unavailable or fails, report that explicitly and output the complete checkpoint in a Markdown code block. State that it has not been persisted and requires manual saving outside the chat. Never report a failed write as a saved checkpoint.
6. Confirm in one line where the checkpoint went: the verified file path, or that it was pasted into the conversation and has not been saved.

## Checkpoint format

Use these headings in this order:

```markdown
# Project / goal

One or two sentences describing this thread of work.

## Current state

Where things stand now, including verification results and unfinished work.

## Decisions made and why

Decisions and their reasoning, not just their outcomes.

## Open questions

Unresolved choices or ambiguities; write "None known" when supported.

## Next steps

Ordered actions for continuing the work.

## Key references

Paths, artifact names, IDs, URLs, and project-specific terminology needed to resume.

## Known pitfalls

Failed approaches or mistakes already caught; write "None known" when supported.
```

Replace the guidance with factual, terse content. Include all seven sections. Keep credentials and secret values out of the checkpoint; reference their configured locations instead.

## Resume from a Chronicle

At the start of a new session where this protocol is loaded, before project work:

1. Check the project's checkpoint location, file list, or platform storage for a matching Chronicle. Ask the user if storage is inaccessible or the project cannot be identified.
2. If one exists, read the relevant checkpoint fully. Prefer the most recent checkpoint for the identified project; ask if multiple candidates are ambiguous. Summarize what was understood in two or three sentences so the user can correct it before work continues. Treat it as recorded context, and verify current files before acting on potentially stale state.
3. If none is found, say so plainly. If the search could not be performed, say it could not be checked rather than claiming no checkpoint exists. Use only the context actually available; never invent continuity.

## Platform notes

- **Claude Design / Projects:** use Project Knowledge only if it is writable from this session. Otherwise offer a file artifact if supported, or the Markdown fallback, and explain that adding it to Project Knowledge is a separate manual step.
- **Claude Cowork:** use its available file tools and the task's existing working-file location.
- **Claude Code, GitHub Copilot, Codex, and other repository agents:** write into the project repository, normally `chronicles/`. A file can be versioned alongside the code; saving it does not mean it has been committed.
- **Replit:** use the project's file tools and confirm a path visible in its file browser.
- **Plain chat:** use the Markdown fallback when no file-write capability exists.

Persistence and automatic loading are separate capabilities. Confirm what the current platform actually supports; a file surviving between sessions does not mean the next assistant will automatically read it.

## Done when

For a checkpoint: all seven sections are present, uncertainties are explicit, and the user has either a verified saved path or the complete fallback with its unsaved status. For a resume: the relevant checkpoint has been read fully and summarized, or its absence or inaccessibility has been reported.
