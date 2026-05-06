'use strict';

const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

const app = express();
const server = http.createServer(app);
const io = new Server(server);

const PORT = process.env.PORT || 3000;

// --- In-memory state ---
const channels = {
  general:    { name: 'general',    description: 'Company-wide announcements', messages: [] },
  random:     { name: 'random',     description: 'Non-work banter',             messages: [] },
  engineering:{ name: 'engineering',description: 'Tech talk',                   messages: [] },
  design:     { name: 'design',     description: 'Design discussions',           messages: [] },
};

// Map of socket.id → { id, username, avatar, status, currentChannel }
const users = new Map();

// Secondary index: username → socket.id  (for fast DM delivery)
const usernameIndex = new Map();

// Map of dmKey (sorted usernames joined with ':') → [{ from, to, text, ts }]
const directMessages = new Map();

// --- Static files ---
app.use(express.static(path.join(__dirname, 'public')));

// --- Socket.io ---
io.on('connection', (socket) => {

  // ── Join / register ─────────────────────────────────────────────────────────
  socket.on('register', ({ username, avatar }) => {
    const user = {
      id:             socket.id,
      username:       username.trim().toLowerCase().replace(/\s+/g, '_'),
      displayName:    username.trim(),
      avatar:         avatar || generateAvatar(username),
      status:         'online',
      currentChannel: 'general',
    };
    if (!user.username) return;   // reject empty usernames
    users.set(socket.id, user);
    usernameIndex.set(user.username, socket.id);

    // Send this user the full channel list and current members
    socket.emit('init', {
      channels: Object.values(channels).map(({ name, description, messages }) => ({
        name,
        description,
        messages: messages.slice(-100),    // last 100 per channel
      })),
      users: [...users.values()],
      me:   user,
    });

    // Broadcast new user to everyone else
    socket.broadcast.emit('user_joined', user);

    // Join the default socket.io room for 'general'
    socket.join('general');
  });

  // ── Channel messaging ────────────────────────────────────────────────────────
  socket.on('join_channel', ({ channel }) => {
    const user = users.get(socket.id);
    if (!user || !channels[channel]) return;

    // Leave old channel room
    socket.leave(user.currentChannel);
    user.currentChannel = channel;
    socket.join(channel);

    socket.emit('channel_history', {
      channel,
      messages: channels[channel].messages.slice(-100),
    });
  });

  socket.on('channel_message', ({ channel, text }) => {
    const user = users.get(socket.id);
    if (!user || !channels[channel] || !text.trim()) return;

    const msg = {
      id:       uuidv4(),
      channel,
      from:     user.username,
      displayName: user.displayName,
      avatar:   user.avatar,
      text:     text.trim(),
      ts:       Date.now(),
    };

    channels[channel].messages.push(msg);
    // Keep channel history bounded to 500 messages
    if (channels[channel].messages.length > 500) {
      channels[channel].messages.shift();
    }

    io.to(channel).emit('channel_message', msg);
  });

  // ── Direct messages ──────────────────────────────────────────────────────────
  socket.on('dm', ({ to, text }) => {
    const from = users.get(socket.id);
    if (!from || !text.trim()) return;

    const toSocketId = usernameIndex.get(to);
    const toUser = toSocketId ? users.get(toSocketId) : null;

    const msg = {
      id:          uuidv4(),
      from:        from.username,
      fromDisplay: from.displayName,
      fromAvatar:  from.avatar,
      to,
      text:        text.trim(),
      ts:          Date.now(),
    };

    if (!directMessages.has(dmKey)) directMessages.set(dmKey, []);
    const history = directMessages.get(dmKey);
    history.push(msg);
    if (history.length > 500) history.shift();

    // Send to sender
    socket.emit('dm', msg);
    // Send to recipient if online
    if (toUser) io.to(toUser.id).emit('dm', msg);
  });

  socket.on('get_dm_history', ({ with: peer }) => {
    const user = users.get(socket.id);
    if (!user) return;
    const dmKey = [user.username, peer].sort().join(':');
    socket.emit('dm_history', {
      with:     peer,
      messages: (directMessages.get(dmKey) || []).slice(-100),
    });
  });

  // ── Typing indicators ────────────────────────────────────────────────────────
  socket.on('typing_start', ({ channel }) => {
    const user = users.get(socket.id);
    if (!user) return;
    socket.to(channel).emit('typing_start', { username: user.displayName, channel });
  });

  socket.on('typing_stop', ({ channel }) => {
    const user = users.get(socket.id);
    if (!user) return;
    socket.to(channel).emit('typing_stop', { username: user.displayName, channel });
  });

  // ── Reactions ────────────────────────────────────────────────────────────────
  socket.on('reaction', ({ messageId, channel, emoji }) => {
    const user = users.get(socket.id);
    if (!user) return;
    const msg = (channels[channel] || { messages: [] }).messages.find(m => m.id === messageId);
    if (!msg) return;

    msg.reactions = msg.reactions || {};
    msg.reactions[emoji] = msg.reactions[emoji] || [];
    const idx = msg.reactions[emoji].indexOf(user.username);
    if (idx === -1) {
      msg.reactions[emoji].push(user.username);
    } else {
      msg.reactions[emoji].splice(idx, 1);
      if (msg.reactions[emoji].length === 0) delete msg.reactions[emoji];
    }
    io.to(channel).emit('reaction_update', { messageId, channel, reactions: msg.reactions });
  });

  // ── Status ───────────────────────────────────────────────────────────────────
  socket.on('set_status', ({ status }) => {
    const user = users.get(socket.id);
    if (!user) return;
    const allowed = ['online', 'away', 'dnd'];
    if (!allowed.includes(status)) return;
    user.status = status;
    io.emit('user_status', { username: user.username, status });
  });

  // ── Disconnect ───────────────────────────────────────────────────────────────
  socket.on('disconnect', () => {
    const user = users.get(socket.id);
    if (!user) return;
    users.delete(socket.id);
    usernameIndex.delete(user.username);
    io.emit('user_left', { username: user.username });
  });
});

// ── Helpers ──────────────────────────────────────────────────────────────────
function generateAvatar(name) {
  const colors = [
    '#E74C3C','#8E44AD','#2980B9','#27AE60',
    '#F39C12','#16A085','#D35400','#2C3E50',
  ];
  const color = colors[name.charCodeAt(0) % colors.length];
  const initials = name.slice(0, 2).toUpperCase();
  return { type: 'initials', color, initials };
}

server.listen(PORT, () => {
  console.log(`\n  🚀  Slack-like app running at http://localhost:${PORT}\n`);
});
