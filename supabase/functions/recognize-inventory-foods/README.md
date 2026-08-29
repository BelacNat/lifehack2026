# Inventory food recognition

This Edge Function accepts a compressed base64 image from the authenticated
Flutter client and returns specific visible food names. It keeps the OpenAI API
key on the server and uses the Responses API with image input and Structured
Outputs.

Deploy and configure it with:

```sh
supabase secrets set OPENAI_API_KEY=your-key
supabase functions deploy recognize-inventory-foods
```

The Flutter client falls back to local ML Kit text recognition when this
function is unavailable.
