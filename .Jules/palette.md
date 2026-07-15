## 2023-11-20 - Generic generic actions
**Learning:** For generic, highly-reusable UI components (like top bar slots or action containers), avoid hardcoding overly generic accessibility descriptions (e.g., 'Action' or 'More options'). Pass descriptions dynamically or allow the implementation to dictate the wording to avoid confusing screen reader announcements.
**Action:** Let parent components define generic descriptions or don't set a default when context is unknown.
