getgenv().M4GIX_CONFIG = {
    URL = "wss://m4gix-ws.onrender.com/",
    PlaceId = 109983668079237,
    Debug = true
}

print("✅ Configuration globale chargée.")

-- // CHARGEMENT DU SCRIPT OBFUSQUÉ
-- Remplace l'URL ci-dessous par le lien vers ton script obfusqué (GitHub, Pastebin, etc.)
loadstring(game:HttpGet("https://ton-lien-vers-le-script-obfusque.lua"))()
