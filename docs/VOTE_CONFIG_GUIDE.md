# Vote Form Configuration Guide

> How to design, configure, and manage per-building vote forms in ComfortOS.

---

## Table of Contents

1. [Overview](#overview)
2. [Schema Structure (v2)](#schema-structure-v2)
3. [Field Types Reference](#field-types-reference)
4. [Option Properties](#option-properties)
5. [Color & Icon Reference](#color--icon-reference)
6. [Complete Examples](#complete-examples)
7. [Facility Manager Frontend Design](#facility-manager-frontend-design)
8. [Backend API Contract](#backend-api-contract)
9. [Best Practices](#best-practices)

---

## Overview

Vote forms in ComfortOS are **Server-Driven UI (SDUI)**. The backend returns a JSON
schema per building and the Flutter app renders the form dynamically —
no app update required to change questions.

Each building can have a **completely different** vote form, configured by its
facility manager through a web-based dashboard.

### How it works

```
┌──────────────────┐       GET /vote-form?building=bldg-001
│  Flutter App      │ ────────────────────────────────────────► Backend API
│  VoteFormWidget   │ ◄──── JSON schema (per-building)  ──────┘
│  renders fields   │
│  dynamically      │       POST /votes
│                   │ ────────────────────────────────────────► Backend API
└──────────────────┘       { payload with user answers }
```

If the server returns `null`, the app uses `DefaultVoteForm.config` as a
fallback.

---

## Schema Structure (v2)

```json
{
  "schemaVersion": 2,
  "formTitle": "Comfort Vote",
  "formDescription": "Quick 1-minute survey about your office environment.",
  "thanksMessage": "Thanks for your feedback!",
  "allowAnonymous": false,
  "cooldownMinutes": 30,
  "fields": [ ... ]
}
```

| Key                | Type     | Required | Description |
|--------------------|----------|----------|-------------|
| `schemaVersion`    | `int`    | Yes      | Always `2` for the current format |
| `formTitle`        | `string` | No       | Bold heading shown above the form |
| `formDescription`  | `string` | No       | Grey subtitle below the title |
| `thanksMessage`    | `string` | No       | Shown after successful submission |
| `allowAnonymous`   | `bool`   | No       | Whether anonymous votes are accepted |
| `cooldownMinutes`  | `int`    | No       | Minimum time between votes per user |
| `fields`           | `array`  | Yes      | Ordered list of form field objects |

---

## Field Types Reference

### `thermal_scale`

7-point ASHRAE thermal comfort scale with colored circles.

```json
{
  "key": "thermal_comfort",
  "type": "thermal_scale",
  "question": "How hot or cold do you feel?",
  "min": 1,
  "max": 7,
  "defaultValue": 4,
  "labels": {
    "1": "Cold",
    "2": "Cool",
    "3": "Slightly Cool",
    "4": "Neutral",
    "5": "Slightly Warm",
    "6": "Warm",
    "7": "Hot"
  }
}
```

**Value produced:** `int` (1–7)

---

### `single_select`

Radio-button-style option group. Supports optional emoji/icon on each option.
Renders as a horizontal row by default, or a `wrap` layout.

```json
{
  "key": "thermal_preference",
  "type": "single_select",
  "question": "Do you want to be warmer or cooler?",
  "layout": "row",
  "options": [
    { "label": "Warmer",   "value": 1, "color": "orange", "emoji": "🔥" },
    { "label": "I am good","value": 2, "color": "green",  "emoji": "👍" },
    { "label": "Cooler",   "value": 3, "color": "blue",   "emoji": "❄️" }
  ]
}
```

**Properties:**
- `layout` — `"row"` (default, evenly spaced) or `"wrap"` (flowing chips)
- Each option: `label`, `value` (int), `color`, optional `emoji` or `icon`

**Value produced:** `int`

---

### `multi_select`

Multi-toggle chip group. Supports emoji/icon on each option.
Supports `exclusive` flag (selecting it deselects all others).

```json
{
  "key": "air_quality",
  "type": "multi_select",
  "question": "What do you think about the air quality?",
  "options": [
    { "label": "Suffocating", "value": "suffocating", "emoji": "😤" },
    { "label": "Humid",       "value": "humid",       "emoji": "💧" },
    { "label": "Dry",         "value": "dry",         "emoji": "🏜️" },
    { "label": "Smelly",      "value": "smelly",      "emoji": "🤢" },
    { "label": "All good!",   "value": "all_good",    "exclusive": true, "color": "green", "emoji": "✅" }
  ]
}
```

**Value produced:** `List<String>` of selected `value` keys

---

### `emoji_scale`

Horizontal row of large emoji buttons with numeric values.
Best for quick mood / comfort captures.

```json
{
  "key": "overall_comfort",
  "type": "emoji_scale",
  "question": "How comfortable is the lab right now?",
  "options": [
    { "emoji": "🥶", "value": 1, "label": "Freezing" },
    { "emoji": "😬", "value": 2, "label": "Chilly" },
    { "emoji": "😊", "value": 3, "label": "Just Right" },
    { "emoji": "😓", "value": 4, "label": "Warm" },
    { "emoji": "🥵", "value": 5, "label": "Too Hot" }
  ]
}
```

**Value produced:** `int`

---

### `emoji_single_select`

Large emoji + label cards, single choice. Good for categorical questions
with visual flair.

```json
{
  "key": "ventilation",
  "type": "emoji_single_select",
  "question": "How is the air ventilation?",
  "options": [
    { "emoji": "💨", "label": "Too Drafty",  "value": 1, "color": "blue" },
    { "emoji": "🌬️", "label": "Good Airflow","value": 2, "color": "green" },
    { "emoji": "😶‍🌫️", "label": "Stuffy",     "value": 3, "color": "orange" }
  ]
}
```

**Value produced:** `int`

---

### `emoji_multi_select`

Large emoji + label cards, multiple choice. Great for "pick all that apply"
with visual differentiation.

```json
{
  "key": "amenities",
  "type": "emoji_multi_select",
  "question": "Which amenities are you enjoying?",
  "options": [
    { "emoji": "☕", "value": "coffee",  "label": "Coffee" },
    { "emoji": "🍕", "value": "food",    "label": "Snacks" },
    { "emoji": "📶", "value": "wifi",    "label": "WiFi" },
    { "emoji": "🪴", "value": "plants",  "label": "Plants" },
    { "emoji": "🎵", "value": "music",   "label": "Music" }
  ]
}
```

**Value produced:** `List<String>` of selected `value` keys

---

### `rating_stars`

Star-based rating from 1 to N.

```json
{
  "key": "lighting",
  "type": "rating_stars",
  "question": "Rate the lighting quality",
  "max": 5,
  "color": "amber"
}
```

| Property | Type    | Default | Description |
|----------|---------|---------|-------------|
| `max`    | `int`   | `5`     | Number of stars |
| `color`  | `string`| `amber` | Star fill color |

**Value produced:** `int` (0 = unset, 1–max)

---

### `text_input`

Free-form text area for open-ended feedback.

```json
{
  "key": "comments",
  "type": "text_input",
  "question": "Any notes for the facility manager?",
  "hint": "E.g., equipment noise, temperature swings…",
  "maxLength": 300,
  "required": false
}
```

| Property    | Type     | Default         | Description |
|-------------|----------|-----------------|-------------|
| `hint`      | `string` | `"Type here…"`  | Placeholder text |
| `maxLength` | `int`    | `500`           | Character limit |
| `required`  | `bool`   | `true`          | Whether field must be filled |

**Value produced:** `String`

---

### `yes_no`

Binary toggle with optional emoji.

```json
{
  "key": "fume_hood",
  "type": "yes_no",
  "question": "Is the fume hood operating properly?",
  "yesLabel": "Yes",
  "noLabel": "No",
  "yesEmoji": "✅",
  "noEmoji": "⚠️"
}
```

| Property   | Type     | Default | Description |
|------------|----------|---------|-------------|
| `yesLabel` | `string` | `Yes`   | Label for Yes button |
| `noLabel`  | `string` | `No`    | Label for No button |
| `yesEmoji` | `string` | —       | Emoji shown inside Yes button |
| `noEmoji`  | `string` | —       | Emoji shown inside No button |

**Value produced:** `bool` (`true` / `false`)

---

### `slider` (legacy)

Standard slider with min/max and optional endpoint labels.

```json
{
  "key": "air_quality",
  "type": "slider",
  "question": "Air Quality",
  "min": 1,
  "max": 5,
  "defaultValue": 3,
  "labels": { "1": "Poor", "3": "OK", "5": "Excellent" }
}
```

**Value produced:** `int`

---

## Option Properties

These properties are shared across option-based field types:

| Property    | Type     | Used By | Description |
|-------------|----------|---------|-------------|
| `label`     | `string` | All     | Display text |
| `value`     | `int\|string` | All | Value sent in payload |
| `emoji`     | `string` | All     | Unicode emoji shown before/above label |
| `icon`      | `string` | `single_select`, `multi_select` | Material icon name |
| `color`     | `string` | All     | Color name for highlights |
| `exclusive` | `bool`   | `multi_select` | Selecting this deselects all others |

> **Priority:** `emoji` takes precedence over `icon`. If both are set, `emoji` is shown.

---

## Color & Icon Reference

### Colors

`orange` · `green` · `blue` · `red` · `amber` · `grey` · `black` ·
`teal` · `purple` · `cyan` · `pink` · `indigo` · `brown` · `lime` ·
`deepOrange` · `yellow`

### Icons (for `icon` property)

`thermostat` · `wb_sunny` · `ac_unit` · `air` · `water_drop` ·
`volume_up` · `volume_off` · `lightbulb` · `light_mode` · `dark_mode` ·
`chair` · `desk` · `meeting_room` · `groups` · `person` ·
`check_circle` · `cancel` · `thumb_up` · `thumb_down` · `star` ·
`favorite` · `eco` · `bolt` · `wifi` · `coffee` ·
`restaurant` · `fitness_center` · `spa` · `warning` · `info`

---

## Complete Examples

### Example 1: Standard Office (bldg-001)

Classic thermal comfort survey with emoji-enhanced options.

```json
{
  "schemaVersion": 2,
  "formTitle": "Comfort Vote",
  "formDescription": "Quick 1-minute survey about your office environment.",
  "thanksMessage": "Thanks for your feedback!",
  "allowAnonymous": false,
  "cooldownMinutes": 30,
  "fields": [
    {
      "key": "thermal_comfort",
      "type": "thermal_scale",
      "question": "How hot or cold do you feel?",
      "min": 1, "max": 7, "defaultValue": 4,
      "labels": { "1": "Cold", "4": "Neutral", "7": "Hot" }
    },
    {
      "key": "thermal_preference",
      "type": "single_select",
      "question": "Do you want to be warmer or cooler?",
      "options": [
        { "label": "Warmer",    "value": 1, "color": "orange", "emoji": "🔥" },
        { "label": "I am good", "value": 2, "color": "green",  "emoji": "👍" },
        { "label": "Cooler",    "value": 3, "color": "blue",   "emoji": "❄️" }
      ]
    },
    {
      "key": "air_quality",
      "type": "multi_select",
      "question": "What do you think about the air quality?",
      "options": [
        { "label": "Suffocating", "value": "suffocating", "emoji": "😤" },
        { "label": "Humid",       "value": "humid",       "emoji": "💧" },
        { "label": "Dry",         "value": "dry",         "emoji": "🏜️" },
        { "label": "Smelly",      "value": "smelly",      "emoji": "🤢" },
        { "label": "All good!",   "value": "all_good",    "exclusive": true, "color": "green", "emoji": "✅" }
      ]
    }
  ]
}
```

### Example 2: Co-Working Space (bldg-004)

Casual vibe-focused survey with emoji scales and star ratings.

```json
{
  "schemaVersion": 2,
  "formTitle": "Space Vibe Check 💬",
  "formDescription": "Tell us how this co-working space feels today.",
  "thanksMessage": "Awesome, thanks for sharing! 🎉",
  "allowAnonymous": true,
  "cooldownMinutes": 15,
  "fields": [
    {
      "key": "overall_mood",
      "type": "emoji_scale",
      "question": "How's the vibe right now?",
      "options": [
        { "emoji": "😞", "value": 1, "label": "Bad" },
        { "emoji": "😐", "value": 2, "label": "Meh" },
        { "emoji": "🙂", "value": 3, "label": "OK" },
        { "emoji": "😄", "value": 4, "label": "Good" },
        { "emoji": "🤩", "value": 5, "label": "Amazing" }
      ]
    },
    {
      "key": "noise_level",
      "type": "emoji_single_select",
      "question": "Noise level?",
      "options": [
        { "emoji": "🤫", "label": "Too Quiet",  "value": 1, "color": "blue" },
        { "emoji": "👌", "label": "Just Right", "value": 2, "color": "green" },
        { "emoji": "📢", "label": "Too Loud",   "value": 3, "color": "red" }
      ]
    },
    {
      "key": "amenities",
      "type": "emoji_multi_select",
      "question": "Which amenities are you enjoying?",
      "options": [
        { "emoji": "☕", "value": "coffee", "label": "Coffee" },
        { "emoji": "🍕", "value": "food",   "label": "Snacks" },
        { "emoji": "📶", "value": "wifi",   "label": "WiFi" },
        { "emoji": "🪴", "value": "plants", "label": "Plants" },
        { "emoji": "🎵", "value": "music",  "label": "Music" }
      ]
    },
    {
      "key": "recommend_rating",
      "type": "rating_stars",
      "question": "Would you recommend this space to a friend?",
      "max": 5,
      "color": "amber"
    }
  ]
}
```

### Example 3: Wellness Centre (bldg-005)

Health-focused with yes/no, symptoms multi-select, and open text.

```json
{
  "schemaVersion": 2,
  "formTitle": "Wellness Environment Survey",
  "formDescription": "Your feedback helps us maintain the healthiest possible environment.",
  "thanksMessage": "Thank you for prioritizing your wellness! 🌿",
  "allowAnonymous": false,
  "cooldownMinutes": 45,
  "fields": [
    {
      "key": "breathing_comfort",
      "type": "emoji_scale",
      "question": "How easy is it to breathe?",
      "options": [
        { "emoji": "😵", "value": 1, "label": "Terrible" },
        { "emoji": "😟", "value": 2, "label": "Poor" },
        { "emoji": "😐", "value": 3, "label": "OK" },
        { "emoji": "😊", "value": 4, "label": "Good" },
        { "emoji": "🌬️", "value": 5, "label": "Fresh" }
      ]
    },
    {
      "key": "thermal_comfort",
      "type": "thermal_scale",
      "question": "How hot or cold do you feel?",
      "min": 1, "max": 7, "defaultValue": 4,
      "labels": { "1": "Cold", "4": "Neutral", "7": "Hot" }
    },
    {
      "key": "scent",
      "type": "yes_no",
      "question": "Can you smell any unpleasant odors?",
      "yesLabel": "Yes 😷",
      "noLabel": "No 😌"
    },
    {
      "key": "symptoms",
      "type": "multi_select",
      "question": "Are you experiencing any of these?",
      "options": [
        { "label": "Headache",   "value": "headache",   "emoji": "🤕" },
        { "label": "Dry eyes",   "value": "dry_eyes",   "emoji": "👁️" },
        { "label": "Fatigue",    "value": "fatigue",     "emoji": "😴" },
        { "label": "Congestion", "value": "congestion",  "emoji": "🤧" },
        { "label": "None",       "value": "none",        "exclusive": true, "color": "green", "emoji": "💪" }
      ]
    },
    {
      "key": "wellness_rating",
      "type": "rating_stars",
      "question": "Rate the overall environment for wellness activities",
      "max": 5,
      "color": "green"
    },
    {
      "key": "feedback",
      "type": "text_input",
      "question": "Any additional wellness feedback?",
      "hint": "E.g., lighting too bright in yoga room, music too loud…",
      "maxLength": 400,
      "required": false
    }
  ]
}
```

---

## Facility Manager Frontend Design

The vote form is designed to be fully configurable through a **facility-manager
web dashboard**. Below is the planned architecture and UX for that frontend.

### Architecture

```
┌─────────────────────────────────────┐
│   Facility Manager Web Dashboard    │
│   (React / Next.js / etc.)          │
│                                     │
│   ┌─────────────┐ ┌──────────────┐  │
│   │ Form Builder │ │ Live Preview │  │
│   │ (drag/drop)  │ │ (phone mock) │  │
│   └─────────────┘ └──────────────┘  │
│            │                        │
│            ▼                        │
│   PUT /api/buildings/{id}/vote-form │───► Backend DB
│                                     │         │
└─────────────────────────────────────┘         │
                                                ▼
                              GET /api/buildings/{id}/vote-form
                                                │
                                      ┌─────────┴─────────┐
                                      │  Flutter App       │
                                      │  VoteFormWidget     │
                                      │  renders it live    │
                                      └────────────────────┘
```

### Form Builder UX

The facility manager web dashboard should provide:

1. **Building selector** — choose which building to configure
2. **Meta settings panel** — form title, description, thanks message,
   anonymous toggle, cooldown slider
3. **Field list** — drag-and-drop reorderable list of fields
4. **Add field** — dropdown of available field types:
   - Thermal Scale
   - Single Select (with emoji/icon options)
   - Multi Select (with emoji/icon options, exclusive toggle)
   - Emoji Scale
   - Emoji Single Select
   - Emoji Multi Select
   - Star Rating
   - Text Input
   - Yes / No
5. **Per-field editor**:
   - Question text
   - Field key (auto-generated from question, editable)
   - Required toggle
   - Type-specific settings (max stars, max length, hint, layout, etc.)
   - Option builder: label, value, emoji picker, icon picker, color picker,
     exclusive toggle
6. **Live preview** — phone-shaped mockup rendering the current schema in
   real-time (could use a Flutter Web embed or a JS re-implementation)
7. **Save & Publish** — saves the JSON schema to the backend
8. **Version history** — rollback to previous form versions

### Backend API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET`  | `/api/buildings/{id}/vote-form` | Returns current form schema (or `null`) |
| `PUT`  | `/api/buildings/{id}/vote-form` | Save new form schema |
| `GET`  | `/api/buildings/{id}/vote-form/history` | List past schema versions |
| `GET`  | `/api/buildings/{id}/vote-form/history/{version}` | Get specific version |
| `POST` | `/api/buildings/{id}/vote-form/preview` | Validate schema without saving |

### Database Schema (planned)

```sql
CREATE TABLE vote_form_configs (
  id            UUID PRIMARY KEY,
  building_id   VARCHAR(50) NOT NULL REFERENCES buildings(id),
  schema_version INT NOT NULL DEFAULT 2,
  config_json   JSONB NOT NULL,
  created_by    VARCHAR(100) NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_active     BOOLEAN NOT NULL DEFAULT true
);

CREATE INDEX idx_vote_form_building ON vote_form_configs(building_id, is_active);
```

### Settings Stored Per Building

| Setting | Where | Description |
|---------|-------|-------------|
| Form schema JSON | `vote_form_configs` | The full SDUI vote form config |
| `allowAnonymous` | Inside schema JSON | Whether anonymous votes are allowed |
| `cooldownMinutes` | Inside schema JSON | Rate limit per user |
| Active version | `is_active` flag | Which schema version is currently served |

---

## Backend API Contract

### GET `/api/buildings/{buildingId}/vote-form`

**Response:** The JSON schema object, or `null` (HTTP 204) if none configured.

The Flutter app calls this in `ApiClient.getVoteFormConfig()` and passes the
result to `VoteFormWidget`. If `null`, `DefaultVoteForm.config` is used.

### POST `/api/votes`

**Request body:**

```json
{
  "voteUuid": "550e8400-e29b-41d4-a716-446655440000",
  "userId": "user-001",
  "buildingId": "bldg-001",
  "schemaVersion": 2,
  "timestamp": "2025-01-15T10:30:00Z",
  "status": "pending",
  "payload": {
    "thermal_comfort": 5,
    "thermal_preference": 2,
    "air_quality": ["all_good"]
  }
}
```

**Payload values by field type:**

| Field Type | Payload Value Type | Example |
|------------|--------------------|---------|
| `thermal_scale` | `int` | `5` |
| `single_select` | `int` | `2` |
| `multi_select` | `List<String>` | `["humid", "dry"]` |
| `emoji_scale` | `int` | `3` |
| `emoji_single_select` | `int` | `2` |
| `emoji_multi_select` | `List<String>` | `["coffee", "wifi"]` |
| `rating_stars` | `int` | `4` |
| `text_input` | `String` | `"Room is too cold"` |
| `yes_no` | `bool` | `true` |
| `slider` | `int` | `3` |

---

## Best Practices

### For Facility Managers

1. **Keep forms short** — 3–5 fields maximum for high response rates
2. **Use emoji liberally** — they increase engagement and reduce cognitive load
3. **Always include a "positive" exclusive option** in multi-select (e.g.,
   "All good! ✅") so occupants can quickly indicate satisfaction
4. **Set appropriate cooldowns** — 15–30 min for co-working, 30–60 min for
   offices, 45–120 min for labs
5. **Use `text_input` sparingly** — mark it `"required": false` to avoid
   survey fatigue
6. **Test on mobile** — use the live preview and verify on a real device

### For Developers

1. **Always handle `null` schemas** — fallback to `DefaultVoteForm.config`
2. **Field `key` must be unique** within a form — it's the payload key
3. **Validate schema server-side** before storing (check required fields,
   option uniqueness, etc.)
4. **Version schemas** — always include `schemaVersion: 2` so the app can
   handle future format changes
5. **Use the `required` field property** — defaults to `true` if omitted;
   set `false` explicitly for optional fields like `text_input`

### Field Type Selection Guide

| Use Case | Recommended Type |
|----------|-----------------|
| ASHRAE thermal comfort (7-point) | `thermal_scale` |
| Simple preference (2–4 options) | `single_select` with emoji |
| Quick mood/feeling capture | `emoji_scale` |
| Categorical with visual flair | `emoji_single_select` |
| "Pick all that apply" complaints | `multi_select` with emoji |
| "Pick all that apply" amenities | `emoji_multi_select` |
| Quality/satisfaction rating | `rating_stars` |
| Binary yes/no question | `yes_no` |
| Open feedback (optional) | `text_input` |
| Legacy numeric scale | `slider` |
