/* ============================================================
   Slack-like App — Client-side JavaScript
   ============================================================ */
'use strict';

const socket = io();

/* ── State ─────────────────────────────────────────────────── */
let me = null;
let activeView = { type: 'channel', id: 'general' };   // { type:'channel'|'dm', id }
let channels = {};   // name → { name, description, messages: [] }
let users    = {};   // username → user
let typingTimers  = {};
let typingUsers   = {};   // channel → Set<displayName>
let unreadCounts  = {};   // channel/dm-key → count
const EMOJIS = ['👍','❤️','😂','🎉','🔥','✅','👀','😮','🙏','💯'];

/* ── DOM refs ───────────────────────────────────────────────── */
const loginOverlay    = document.getElementById('login-overlay');
const usernameInput   = document.getElementById('username-input');
const loginBtn        = document.getElementById('login-btn');

const channelHeader   = document.getElementById('channel-header');
const channelTitle    = document.getElementById('channel-title');
const channelDesc     = document.getElementById('channel-desc');
const memberCount     = document.getElementById('member-count');
const messagesEl      = document.getElementById('messages');
const typingBar       = document.getElementById('typing-bar');
const messageInput    = document.getElementById('message-input');
const sendBtn         = document.getElementById('send-btn');
const emojiBtn        = document.getElementById('emoji-btn');
const emojiPicker     = document.getElementById('emoji-picker');
const channelList     = document.getElementById('channel-list');
const dmList          = document.getElementById('dm-list');
const memberList      = document.getElementById('member-list');
const userStatusLine  = document.getElementById('user-status-line');
const userStatusDot   = document.getElementById('user-status-dot');
const userDisplayName = document.getElementById('user-display-name');
const toastContainer  = document.getElementById('toast-container');

/* ── Login ──────────────────────────────────────────────────── */
loginBtn.addEventListener('click', doLogin);
usernameInput.addEventListener('keydown', e => { if (e.key === 'Enter') doLogin(); });

function doLogin() {
  const name = usernameInput.value.trim();
  if (!name) { usernameInput.focus(); return; }
  socket.emit('register', { username: name });
  loginOverlay.classList.add('hidden');
}

/* ── Socket events ──────────────────────────────────────────── */
socket.on('init', (data) => {
  me = data.me;
  userDisplayName.textContent = me.displayName;

  // Seed channels
  data.channels.forEach(ch => {
    channels[ch.name] = { ...ch };
    unreadCounts[ch.name] = 0;
  });

  // Seed users
  data.users.forEach(u => { users[u.username] = u; });

  renderSidebar();
  switchTo('channel', 'general');
});

socket.on('user_joined', (user) => {
  users[user.username] = user;
  renderSidebar();
  showToast(`${user.displayName} joined`);
});

socket.on('user_left', ({ username }) => {
  if (users[username]) {
    showToast(`${users[username].displayName} left`);
    delete users[username];
  }
  renderSidebar();
});

socket.on('user_status', ({ username, status }) => {
  if (users[username]) users[username].status = status;
  renderSidebar();
  if (me && username === me.username) setStatusDot(status);
});

socket.on('channel_history', ({ channel, messages }) => {
  channels[channel].messages = messages;
  if (activeView.type === 'channel' && activeView.id === channel) {
    renderMessages();
  }
});

socket.on('channel_message', (msg) => {
  channels[msg.channel].messages.push(msg);
  if (activeView.type === 'channel' && activeView.id === msg.channel) {
    appendMessage(msg);
    clearTypingFor(msg.channel);
  } else {
    unreadCounts[msg.channel] = (unreadCounts[msg.channel] || 0) + 1;
    renderSidebar();
    showToast(`#${msg.channel}: ${msg.displayName}: ${msg.text}`, 3000);
  }
});

socket.on('dm', (msg) => {
  const peer = msg.from === me.username ? msg.to : msg.from;
  const dmKey = makeDmKey(peer);

  if (!channels['__dm_' + peer]) channels['__dm_' + peer] = { messages: [] };
  channels['__dm_' + peer].messages.push(msg);

  if (activeView.type === 'dm' && activeView.id === peer) {
    appendDmMessage(msg);
  } else if (msg.from !== me.username) {
    unreadCounts[dmKey] = (unreadCounts[dmKey] || 0) + 1;
    renderSidebar();
    showToast(`DM from ${msg.fromDisplay}: ${msg.text}`, 4000);
  }
});

socket.on('dm_history', ({ with: peer, messages }) => {
  channels['__dm_' + peer] = { messages };
  if (activeView.type === 'dm' && activeView.id === peer) {
    renderMessages();
  }
});

socket.on('typing_start', ({ username, channel }) => {
  if (activeView.type === 'channel' && activeView.id === channel) {
    typingUsers[channel] = typingUsers[channel] || new Set();
    typingUsers[channel].add(username);
    renderTyping(channel);
  }
});
socket.on('typing_stop', ({ username, channel }) => {
  if (typingUsers[channel]) {
    typingUsers[channel].delete(username);
    renderTyping(channel);
  }
});

socket.on('reaction_update', ({ messageId, channel, reactions }) => {
  const msg = channels[channel]?.messages.find(m => m.id === messageId);
  if (msg) {
    msg.reactions = reactions;
    const chip = document.querySelector(`.msg-reactions[data-id="${messageId}"]`);
    if (chip) renderReactions(chip, messageId, channel, reactions);
  }
});

/* ── Navigation ─────────────────────────────────────────────── */
function switchTo(type, id) {
  activeView = { type, id };
  typingBar.textContent = '';

  // Clear unread
  const key = type === 'channel' ? id : makeDmKey(id);
  unreadCounts[key] = 0;

  if (type === 'channel') {
    const ch = channels[id];
    channelTitle.textContent = `# ${id}`;
    channelDesc.textContent  = ch?.description || '';
    socket.emit('join_channel', { channel: id });
    renderMessages();
  } else {
    const peer = users[id];
    channelTitle.textContent = peer?.displayName || id;
    channelDesc.textContent  = 'Direct message';
    socket.emit('get_dm_history', { with: id });
    renderMessages();
  }

  updateMemberCount();
  renderSidebar();
}

/* ── Sidebar render ─────────────────────────────────────────── */
function renderSidebar() {
  // Channels
  channelList.innerHTML = '';
  Object.keys(channels)
    .filter(k => !k.startsWith('__dm_'))
    .forEach(name => {
      const item = document.createElement('div');
      item.className = 'sidebar-item' + (activeView.type === 'channel' && activeView.id === name ? ' active' : '');
      const unread = unreadCounts[name] || 0;
      item.innerHTML = `<span class="channel-prefix">#</span> ${escHtml(name)}${unread ? `<span class="unread-badge">${unread}</span>` : ''}`;
      item.addEventListener('click', () => switchTo('channel', name));
      channelList.appendChild(item);
    });

  // DMs — show all other online users + any open DM threads
  dmList.innerHTML = '';
  const dmUsers = new Set([
    ...Object.keys(users).filter(u => u !== me?.username),
  ]);

  dmUsers.forEach(username => {
    const u = users[username];
    if (!u) return;
    const key = makeDmKey(username);
    const unread = unreadCounts[key] || 0;
    const isActive = activeView.type === 'dm' && activeView.id === username;
    const item = document.createElement('div');
    item.className = 'sidebar-item' + (isActive ? ' active' : '');

    const avatarHtml = buildAvatarHtml(u.avatar, 20, 3);
    item.innerHTML = `
      <div class="dm-avatar-wrap">
        ${avatarHtml}
        <div class="dm-status-dot ${u.status || 'offline'}"></div>
      </div>
      <span>${escHtml(u.displayName)}</span>
      ${unread ? `<span class="unread-badge">${unread}</span>` : ''}`;
    item.addEventListener('click', () => switchTo('dm', username));
    dmList.appendChild(item);
  });

  // Member list (right panel)
  memberList.innerHTML = '';
  const sorted = Object.values(users).sort((a, b) => {
    const order = { online: 0, away: 1, dnd: 2, offline: 3 };
    return (order[a.status] ?? 3) - (order[b.status] ?? 3);
  });
  sorted.forEach(u => {
    const item = document.createElement('div');
    item.className = 'member-item';
    const avatarHtml = buildMemberAvatarHtml(u.avatar, u.status);
    item.innerHTML = `
      ${avatarHtml}
      <span class="member-name${u.username === me?.username ? ' you' : ''}">${escHtml(u.displayName)}${u.username === me?.username ? ' (you)' : ''}</span>`;
    item.addEventListener('click', () => {
      if (u.username !== me?.username) switchTo('dm', u.username);
    });
    memberList.appendChild(item);
  });

  updateMemberCount();
}

/* ── Messages render ────────────────────────────────────────── */
function renderMessages() {
  messagesEl.innerHTML = '';

  if (activeView.type === 'channel') {
    const msgs = channels[activeView.id]?.messages || [];
    renderMessageList(msgs, false);
  } else {
    const msgs = channels['__dm_' + activeView.id]?.messages || [];
    renderMessageList(msgs, true);
  }
  scrollToBottom();
}

function renderMessageList(msgs, isDm) {
  let prevAuthor = null;
  let prevDate   = null;

  msgs.forEach((msg, idx) => {
    const msgDate = formatDate(msg.ts);
    if (msgDate !== prevDate) {
      messagesEl.appendChild(makeDateDivider(msgDate));
      prevDate = msgDate;
      prevAuthor = null;
    }
    const isContinuation = !isDm && msg.from === prevAuthor && idx > 0;
    messagesEl.appendChild(buildMsgEl(msg, isContinuation, isDm));
    prevAuthor = msg.from;
  });
}

function appendMessage(msg) {
  const msgs = channels[msg.channel]?.messages || [];
  const idx = msgs.length - 1;
  const prev = msgs[idx - 1];
  const isContinuation = prev && prev.from === msg.from;

  const msgDate = formatDate(msg.ts);
  const lastDivider = messagesEl.querySelector('.date-divider:last-of-type');
  if (!lastDivider || lastDivider.dataset.date !== msgDate) {
    messagesEl.appendChild(makeDateDivider(msgDate));
  }
  messagesEl.appendChild(buildMsgEl(msg, isContinuation, false));
  scrollToBottom();
}

function appendDmMessage(msg) {
  const msgs = channels['__dm_' + (msg.from === me.username ? msg.to : msg.from)]?.messages || [];
  const isContinuation = false;
  messagesEl.appendChild(buildMsgEl(msg, isContinuation, true));
  scrollToBottom();
}

function buildMsgEl(msg, isContinuation, isDm) {
  const div = document.createElement('div');
  div.className = 'msg-group' + (isContinuation ? ' continuation' : '');
  div.dataset.id = msg.id;

  const author = isDm ? (msg.from === me?.username ? me : users[msg.from]) : users[msg.from];
  const avatar = author?.avatar || { type: 'initials', color: '#1264a3', initials: '??' };

  div.innerHTML = `
    ${buildAvatarHtml(avatar, 36, 4)}
    <div class="msg-body">
      <div class="msg-meta">
        <span class="msg-author">${escHtml(msg.displayName || msg.fromDisplay || msg.from)}</span>
        <span class="msg-time">${formatTime(msg.ts)}</span>
      </div>
      <div class="msg-text">${escHtml(msg.text)}</div>
      <div class="msg-reactions" data-id="${msg.id}"></div>
    </div>`;

  if (msg.reactions && Object.keys(msg.reactions).length > 0) {
    const reactEl = div.querySelector('.msg-reactions');
    renderReactions(reactEl, msg.id, msg.channel || activeView.id, msg.reactions);
  }

  // Add reaction on double-click
  div.addEventListener('dblclick', () => showEmojiReactionMenu(div, msg));

  return div;
}

function renderReactions(container, msgId, channel, reactions) {
  container.innerHTML = '';
  Object.entries(reactions).forEach(([emoji, users]) => {
    if (!users.length) return;
    const chip = document.createElement('span');
    chip.className = 'reaction-chip' + (users.includes(me?.username) ? ' mine' : '');
    chip.textContent = `${emoji} ${users.length}`;
    chip.title = users.join(', ');
    chip.addEventListener('click', () => {
      socket.emit('reaction', { messageId: msgId, channel, emoji });
    });
    container.appendChild(chip);
  });
}

/* ── Emoji reaction context menu ────────────────────────────── */
function showEmojiReactionMenu(msgEl, msg) {
  const existing = document.getElementById('reaction-menu');
  if (existing) existing.remove();

  const menu = document.createElement('div');
  menu.id = 'reaction-menu';
  menu.style.cssText = `
    position: fixed; background: #fff;
    border: 1px solid #ddd; border-radius: 8px;
    padding: 8px; box-shadow: 0 4px 16px rgba(0,0,0,.15);
    display: flex; gap: 4px; z-index: 50;
  `;
  EMOJIS.forEach(e => {
    const btn = document.createElement('span');
    btn.className = 'emoji-opt';
    btn.textContent = e;
    btn.addEventListener('click', () => {
      socket.emit('reaction', {
        messageId: msg.id,
        channel: msg.channel || activeView.id,
        emoji: e,
      });
      menu.remove();
    });
    menu.appendChild(btn);
  });

  const rect = msgEl.getBoundingClientRect();
  menu.style.top  = `${rect.top - 60}px`;
  menu.style.left = `${rect.left + 46}px`;
  document.body.appendChild(menu);

  const close = (ev) => { if (!menu.contains(ev.target)) { menu.remove(); document.removeEventListener('click', close); } };
  setTimeout(() => document.addEventListener('click', close), 0);
}

/* ── Typing ─────────────────────────────────────────────────── */
let isTyping = false;

messageInput.addEventListener('input', () => {
  if (!me) return;
  if (activeView.type !== 'channel') return;
  if (!isTyping) {
    isTyping = true;
    socket.emit('typing_start', { channel: activeView.id });
  }
  clearTimeout(typingTimers[activeView.id]);
  typingTimers[activeView.id] = setTimeout(() => {
    isTyping = false;
    socket.emit('typing_stop', { channel: activeView.id });
  }, 2000);
});

function renderTyping(channel) {
  const set = typingUsers[channel];
  if (!set || set.size === 0) {
    typingBar.textContent = '';
    return;
  }
  const arr = [...set];
  if (arr.length === 1)      typingBar.textContent = `${arr[0]} is typing…`;
  else if (arr.length === 2) typingBar.textContent = `${arr[0]} and ${arr[1]} are typing…`;
  else                       typingBar.textContent = `${arr.length} people are typing…`;
}

function clearTypingFor(channel) {
  typingUsers[channel] = new Set();
  if (activeView.type === 'channel' && activeView.id === channel) {
    typingBar.textContent = '';
  }
}

/* ── Send message ────────────────────────────────────────────── */
messageInput.addEventListener('keydown', e => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    sendMessage();
  }
});
sendBtn.addEventListener('click', sendMessage);

function sendMessage() {
  const text = messageInput.value.trim();
  if (!text || !me) return;
  messageInput.value = '';
  isTyping = false;
  if (activeView.type === 'channel') {
    socket.emit('channel_message', { channel: activeView.id, text });
    socket.emit('typing_stop', { channel: activeView.id });
  } else {
    socket.emit('dm', { to: activeView.id, text });
  }
  autoResize();
}

/* ── Emoji picker ───────────────────────────────────────────── */
EMOJIS.forEach(e => {
  const el = document.createElement('span');
  el.className = 'emoji-opt';
  el.textContent = e;
  el.addEventListener('click', () => {
    messageInput.value += e;
    emojiPicker.classList.remove('open');
    messageInput.focus();
  });
  emojiPicker.appendChild(el);
});

emojiBtn.addEventListener('click', (ev) => {
  ev.stopPropagation();
  emojiPicker.classList.toggle('open');
});
document.addEventListener('click', () => emojiPicker.classList.remove('open'));
emojiPicker.addEventListener('click', e => e.stopPropagation());

/* ── Textarea auto-resize ────────────────────────────────────── */
messageInput.addEventListener('input', autoResize);
function autoResize() {
  messageInput.style.height = 'auto';
  messageInput.style.height = Math.min(messageInput.scrollHeight, 160) + 'px';
}

/* ── Status toggle ───────────────────────────────────────────── */
const statuses = ['online', 'away', 'dnd'];
userStatusLine.addEventListener('click', () => {
  if (!me) return;
  const next = statuses[(statuses.indexOf(me.status) + 1) % statuses.length];
  me.status = next;
  socket.emit('set_status', { status: next });
  setStatusDot(next);
});

function setStatusDot(status) {
  const colors = { online: '#2bac76', away: '#e8a723', dnd: '#e01e5a' };
  userStatusDot.style.background = colors[status] || '#616061';
}

/* ── Helpers ─────────────────────────────────────────────────── */
function makeDmKey(peer) {
  if (!me) return peer;
  return [me.username, peer].sort().join(':');
}

function buildAvatarHtml(av, size, radius) {
  if (!av) return `<div class="avatar" style="width:${size}px;height:${size}px;border-radius:${radius}px;background:#1264a3">?</div>`;
  return `<div class="avatar" style="width:${size}px;height:${size}px;border-radius:${radius}px;background:${av.color};font-size:${Math.round(size * .38)}px">${av.initials}</div>`;
}

function buildMemberAvatarHtml(av, status) {
  const color = av?.color || '#1264a3';
  const initials = av?.initials || '??';
  return `
    <div class="member-avatar" style="background:${color}">
      ${initials}
      <div class="member-status-dot ${status || 'offline'}"></div>
    </div>`;
}

function updateMemberCount() {
  const total = Object.keys(users).length;
  memberCount.innerHTML = `<span>👥</span> ${total} member${total !== 1 ? 's' : ''}`;
}

function scrollToBottom() {
  messagesEl.scrollTop = messagesEl.scrollHeight;
}

function makeDateDivider(label) {
  const d = document.createElement('div');
  d.className = 'date-divider';
  d.dataset.date = label;
  d.innerHTML = `<span>${label}</span>`;
  return d;
}

function formatDate(ts) {
  const d = new Date(ts);
  const today = new Date();
  const yesterday = new Date(today); yesterday.setDate(today.getDate() - 1);
  if (sameDay(d, today))     return 'Today';
  if (sameDay(d, yesterday)) return 'Yesterday';
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
}

function sameDay(a, b) {
  return a.getFullYear() === b.getFullYear() &&
         a.getMonth()    === b.getMonth()    &&
         a.getDate()     === b.getDate();
}

function formatTime(ts) {
  return new Date(ts).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' });
}

function escHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function showToast(msg, duration = 3000) {
  const el = document.createElement('div');
  el.className = 'toast';
  el.textContent = msg;
  toastContainer.appendChild(el);
  setTimeout(() => { el.style.opacity = '0'; el.style.transition = 'opacity .3s'; setTimeout(() => el.remove(), 350); }, duration);
}
