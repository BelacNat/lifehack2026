# Rescue My Fridge

This feature reads and writes the existing Supabase `fridge_items` table. It
does not create or alter any tables, columns, policies, or migrations.

## Included

- Expiry urgency calculated from each item's expiry date
- Rescue-only view for unconsumed food expiring soon
- Supabase-backed consumed actions
- AI rescue recipes placed before the urgent-food list
- Pull-to-refresh and database error handling
- Automatic AI recipes using all safe, unconsumed food
- Rescue-soon ingredients prioritized ahead of fresher food
- Expandable recipe results with no manual recipe input required

## OpenAI recipe contract

The Flutter client calls the Supabase Edge Function
`openai-recipe-suggestions`. The deployed function keeps `OPENAI_API_KEY` in
server-side secrets and calls the OpenAI Responses API with Structured Outputs.
It uses `gpt-4o-mini`, requires a valid Supabase JWT, validates request data,
and excludes expired ingredients before recipe generation.

Client request:

```json
{
  "ingredients": [
    {
      "name": "Baby spinach",
      "quantity": 1,
      "unit": "bag",
      "days_until_expiry": 0
    }
  ],
  "recipe_count": 3
}
```

Expected function response:

```json
{
  "recipes": [
    {
      "title": "Recipe title",
      "summary": "Short description",
      "time_minutes": 20,
      "difficulty": "Easy",
      "ingredients_used": ["Baby spinach"],
      "steps": ["First step", "Second step"],
      "waste_saving_tip": "Storage or reuse advice"
    }
  ]
}
```

Reference: [OpenAI Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs)
