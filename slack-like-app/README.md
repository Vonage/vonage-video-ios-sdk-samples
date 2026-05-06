# Slack-like Chat App

A real-time, locally-hosted chat application inspired by Slack — built with **Node.js**, **Express**, and **Socket.io**.

## Features

| Feature | Details |
|---|---|
| 💬 Channels | `#general`, `#random`, `#engineering`, `#design` |
| 📨 Direct Messages | Click any user in the sidebar or member list |
| 👤 Presence | Online / Away / DND — click your name to cycle through |
| ⌨️ Typing indicators | See who's typing in real time |
| 😀 Emoji reactions | Double-click any message to react; click a reaction to toggle |
| 🔔 Toast notifications | New messages in other channels / DMs pop up in the corner |
| 📜 Message history | Last 100 messages are delivered on join (in-memory, resets on restart) |

## Quick Start

### Prerequisites
- [Node.js](https://nodejs.org/) v18 or higher

### Run

```bash
cd slack-like-app
npm install       # only needed once
npm start
```

Then open **http://localhost:3000** in your browser.

Open multiple tabs (or share the URL on your local network) to chat with multiple users.

## Usage

1. **Enter a display name** on the login screen and press **Start chatting**.
2. Click a **channel** in the left sidebar to switch channels.
3. Click a **username** in the sidebar or the Members panel to open a DM.
4. Press **Enter** to send, **Shift+Enter** for a new line.
5. **Double-click** a message to react with an emoji.
6. Click your **name / status dot** in the top-left to cycle your status.

## Architecture

```
slack-like-app/
├── server.js          # Express + Socket.io server (all state in-memory)
├── package.json
└── public/
    ├── index.html     # Single-page app shell + login overlay
    ├── css/style.css  # Slack-inspired dark-sidebar theme
    └── js/app.js      # Client-side Socket.io event handling & rendering
```

All data lives in the server process memory — no database required.
Restarting the server clears all messages and user sessions.

## Customisation

- **Add channels**: edit the `channels` object at the top of `server.js`.
- **Change port**: set the `PORT` environment variable, e.g. `PORT=8080 npm start`.
- **Persist messages**: replace the in-memory arrays with a JSON file, SQLite, or any database.
