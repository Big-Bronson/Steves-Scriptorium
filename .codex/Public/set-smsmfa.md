## Public\set-smsmfa.ps1

### What This File Does
When run by an MSP helpdesk engineer, this script interactively updates the phone number associated with an existing SMS or phone-based MFA method for a specified Microsoft 365 user. The engineer provides a user's UPN, selects which phone method to modify from a list, supplies a new phone number in E.164 format, and the script applies the change via Microsoft Graph.

### Why It Exists
MFA phone numbers become outdated regularly—users change devices, upgrade carriers, or port numbers. Rather than forcing engineers to navigate the Azure portal or use raw Graph API calls with method IDs, this script provides a guided, interactive workflow that lists the user's current phone methods, lets the engineer pick which one to change, and safely updates it. It pairs with `add-smsmfa` (which registers new methods) and `get-smsmfa` (which lists them) to form a complete phone MFA management toolkit.

### What It Protects Against
- **User lookup failure**: Script validates that the UPN exists and is found in the tenant before attempting to fetch methods, avoiding cryptic Graph errors downstream.
- **No methods registered**: Script detects when a user has zero phone methods and gracefully exits with guidance to use `add-smsmfa` first, rather than throwing an error.
- **Out-of-range selection**: Script validates that the user's numeric choice is actually a valid index (1 to method count), rejecting non-numeric or out-of-bounds input.
- **Empty phone number input**: Script refuses to proceed if the user submits a blank phone number, preventing accidental nullification.
- **Graph permission gap**: Script auto-connects with the required `UserAuthenticationMethod.ReadWrite.All` scope if no Graph context exists, avoiding "permission denied" surprises mid-execution.

### Invariants
- A valid Microsoft Graph context with `UserAuthenticationMethod.ReadWrite.All` scope must exist (or be auto-created) before the script finishes.
- The target user must exist in the tenant and be queryable by UPN.
- At least one phone authentication method must already be registered on that user's account.
- The phone number supplied must be in E.164 format (e.g., `+61412345678`) for the Graph API to accept it.

### Evolution Notes
This file was introduced in a single commit on 2026-05-08 as part of a new MFA management family and has not changed since. It arrived fully formed, with all validation logic, user prompts, and error handling already in place.

### Change Log
- 2026-05-08: Initial commit; added interactive phone MFA update workflow with UPN lookup, method selection, and E.164 validation.