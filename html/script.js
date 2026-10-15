const content = document.querySelector('.content');
const hudStats = document.querySelector('#hudStats');
const arenaGrid = document.querySelector('#appendhere');
const leaderboardBody = document.querySelector('#leaderboardBody');
const leaderboardEmpty = document.querySelector('#leaderboardEmpty');
const lbPodium = document.querySelector('#lbPodium');
const lbTableHead = document.querySelector('#lbTableHead');
const onlineCount = document.querySelector('#onlineCount');
const lobbyCount = document.querySelector('#lobbyCount');

// in-match HUD
const killsValue = document.querySelector('#kills');
const deathsValue = document.querySelector('#tode');
const kdValue = document.querySelector('#kd');
// profile rail
const profKills = document.querySelector('#profKills');
const profDeaths = document.querySelector('#profDeaths');
const profKd = document.querySelector('#profKd');
// rank card
const rankCard = document.querySelector('#rankCard');
const rankBadge = document.querySelector('#rankBadge');
const rankName = document.querySelector('#rankName');
const ratingValue = document.querySelector('#ratingValue');
const nextRankLabel = document.querySelector('#nextRankLabel');
const rankProgressPct = document.querySelector('#rankProgressPct');
const rankBarFill = document.querySelector('#rankBarFill');
const seasonLabel = document.querySelector('#seasonLabel');
// modal
const profileModal = document.querySelector('#profileModal');

// Scoreboard elements
const sbOverlay = document.querySelector('#sbOverlay');
const sbZoneName = document.querySelector('#sbZoneName');
const sbKills = document.querySelector('#sbKills');
const sbDeaths = document.querySelector('#sbDeaths');
const sbKd = document.querySelector('#sbKd');
const sbRankBox = document.querySelector('#sbRankBox');
const sbRankIcon = document.querySelector('#sbRankIcon');
const sbRankName = document.querySelector('#sbRankName');
const sbRating = document.querySelector('#sbRating');
const sbPlayerList = document.querySelector('#sbPlayerList');

const RESOURCE = 'wx_ffa';
let arenas = [];

content.style.display = 'none';
hudStats.style.display = 'none';

/* ---------------- NUI message bus ---------------- */
window.addEventListener('message', (event) => {
    const item = event.data || {};

    switch (item.action) {
        case 'openMenu':
            item.status === true ? openMenu() : closeMenu(false);
            return;
        case 'profile':
            applyProfile(item);
            return;
        case 'leaderboard':
            renderLeaderboard(item.players || []);
            return;
        case 'showScoreboard':
            renderScoreboard(item);
            return;
    }

    if (item.type === 'add') {
        addArena(item.label, item.picture, item.player, item.modus);
        return;
    }

    if (item.stats === true) {
        showHud(item.kills, item.tode, item.kd);
        if (item.alwaysShow === true) {
            hudStats.style.display = 'flex';
        }
    } else if (item.stats === false || (item.type === 'ui' && item.display === false)) {
        hudStats.style.display = 'none';
    }
});

/* ---------------- Tabs ---------------- */
document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => switchTab(tab.dataset.tab));
});

function switchTab(name) {
    document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t.dataset.tab === name));
    document.querySelectorAll('.view').forEach((v) => v.classList.toggle('active', v.dataset.view === name));
}

/* ---------------- Close / refresh ---------------- */
document.querySelector('#closeButton').addEventListener('click', () => closeMenu(true));
document.querySelector('#refreshBoard').addEventListener('click', () => post('refreshLeaderboard'));

document.addEventListener('keyup', (e) => {
    if (e.key !== 'Escape') return;
    if (profileModal.classList.contains('show')) { closeProfileModal(); return; }
    if (content.style.display !== 'none') closeMenu(true);
});

/* ---------------- Menu open/close ---------------- */
function openMenu() {
    switchTab('arenas');
    content.style.display = 'grid';
    requestAnimationFrame(() => content.classList.add('is-visible'));
}

function closeMenu(sendCallback) {
    content.classList.remove('is-visible');
    setTimeout(() => { content.style.display = 'none'; }, 160);

    arenas = [];
    arenaGrid.innerHTML = '';
    if (sendCallback) post('close');
}

/* ---------------- In-match HUD + profile ---------------- */
function showHud(kills, deaths, kd) {
    killsValue.textContent = kills;
    deathsValue.textContent = deaths;
    kdValue.textContent = formatKd(kd);
    setProfile(kills, deaths, kd);

    if (sbOverlay.classList.contains('show')) {
        if (kills != null) sbKills.textContent = kills;
        if (deaths != null) sbDeaths.textContent = deaths;
        if (kd != null) sbKd.textContent = formatKd(kd);
    }
}

/* ---------------- Hold-to-Show Transparent Scoreboard ---------------- */
function renderScoreboard(item) {
    if (!item.visible) {
        sbOverlay.classList.remove('show');
        sbOverlay.setAttribute('aria-hidden', 'true');
        return;
    }

    if (item.zone) sbZoneName.textContent = item.zone.toUpperCase();
    sbKills.textContent = item.kills ?? 0;
    sbDeaths.textContent = item.tode ?? 0;
    sbKd.textContent = formatKd(item.kd);

    if (item.rankName) {
        const color = item.rankColor || '#8ea0cc';
        sbRankBox.style.setProperty('--sb-rank-color', color);
        sbRankIcon.textContent = item.rankIcon || 'R';
        sbRankName.textContent = item.rankName;
        sbRating.textContent = `${item.rating ?? 0} RR`;
    }

    renderScoreboardPlayers(item.players || []);

    sbOverlay.classList.add('show');
    sbOverlay.setAttribute('aria-hidden', 'false');
}

function renderScoreboardPlayers(players) {
    sbPlayerList.innerHTML = '';

    if (!players.length) {
        sbPlayerList.innerHTML = '<div class="sb-empty-msg">No active players in this arena.</div>';
        return;
    }

    players.forEach((p, index) => {
        const rank = index + 1;
        const row = document.createElement('div');
        row.className = 'sb-row' + (p.isSelf ? ' is-self' : '');
        row.innerHTML = `
            <span class="sb-col-rank">#${rank}</span>
            <span class="sb-col-player">
                <span class="sb-pname">${escapeHtml(p.name || 'Unknown Soldier')}</span>
                ${p.isSelf ? '<span class="sb-me-tag">YOU</span>' : ''}
            </span>
            <span class="sb-col-kills">${p.kills ?? 0}</span>
            <span class="sb-col-deaths">${p.deaths ?? 0}</span>
            <span class="sb-col-kd">${formatKd(p.kd)}</span>
        `;
        sbPlayerList.appendChild(row);
    });
}

function setProfile(kills, deaths, kd) {
    if (kills != null) profKills.textContent = kills;
    if (deaths != null) profDeaths.textContent = deaths;
    if (kd != null) profKd.textContent = formatKd(kd);
}

function applyProfile(item) {
    setProfile(item.kills, item.tode, item.kd);

    const color = item.rankColor || '#8ea0cc';
    rankCard.style.setProperty('--rank-color', color);
    rankBadge.textContent = item.rankIcon || 'R';
    rankName.textContent = item.rankName || 'Recruit';
    ratingValue.textContent = `${item.rating ?? 0} RR`;
    rankBarFill.style.width = `${item.rankProgress ?? 0}%`;
    rankProgressPct.textContent = `${item.rankProgress ?? 0}%`;
    nextRankLabel.textContent = item.nextRank ? `Next: ${item.nextRank}` : 'Max rank reached';
    if (item.season) seasonLabel.textContent = `Live · ${item.season}`;
}

/* ---------------- Arenas ---------------- */
function addArena(label, picture, player, modus) {
    arenas.push({ label, picture, player, modus });
    renderArenaCard(arenas[arenas.length - 1]);
    lobbyCount.textContent = arenas.length;
    onlineCount.textContent = totalPlayers();
}

function totalPlayers() {
    return arenas.reduce((sum, a) => {
        const m = String(a.player).match(/(\d+)\s*\//);
        return sum + (m ? Number(m[1]) : 0);
    }, 0);
}

function capacityPercent(text) {
    const m = String(text).match(/(\d+)\s*\/\s*(\d+)/);
    if (!m || !Number(m[2])) return { pct: 0, current: 0, max: 0 };
    return { pct: Math.min(100, Math.round((Number(m[1]) / Number(m[2])) * 100)), current: Number(m[1]), max: Number(m[2]) };
}

function renderArenaCard(arena) {
    const cap = capacityPercent(arena.player);
    const isFull = cap.max > 0 && cap.current >= cap.max;

    const card = document.createElement('div');
    card.className = 'arena-card' + (isFull ? ' full' : '');
    card.innerHTML = `
        <div class="arena-thumb">
            <span class="arena-badge ${isFull ? 'full' : ''}"><span class="dot"></span>${arena.player}</span>
            <span class="arena-mode">${escapeHtml(arena.modus || 'Mode')}</span>
            <img src="${escapeAttr(arena.picture)}" alt="" onerror="this.style.display='none'">
        </div>
        <div class="arena-info">
            <div class="arena-name">${escapeHtml(arena.label)}</div>
            <div class="arena-cap">
                <div class="arena-cap-text"><span>Capacity</span><span>${cap.pct}%</span></div>
                <div class="cap-bar"><span style="width:${cap.pct}%"></span></div>
            </div>
            <button class="deploy-btn" type="button">${isFull ? 'Arena Full' : 'Deploy'}</button>
        </div>`;

    const btn = card.querySelector('.deploy-btn');
    if (!isFull) btn.addEventListener('click', () => deploy(arena.label));
    arenaGrid.appendChild(card);
}

function deploy(label) {
    post('select', { label });
}

/* ---------------- Leaderboard ---------------- */
function renderLeaderboard(players) {
    leaderboardBody.innerHTML = '';
    lbPodium.innerHTML = '';
    lbTableHead.style.display = 'none';

    if (!players.length) {
        leaderboardEmpty.classList.add('show');
        return;
    }
    leaderboardEmpty.classList.remove('show');

    const top3 = players.filter(p => (p.rank || 0) <= 3 && (p.rank || 0) >= 1);
    const rest = players.filter(p => (p.rank || 0) > 3);

    // podium order: 2nd, 1st, 3rd
    const podiumOrder = [
        top3.find(p => p.rank === 2),
        top3.find(p => p.rank === 1),
        top3.find(p => p.rank === 3),
    ].filter(Boolean);

    const medals = { 1: '🥇', 2: '🥈', 3: '🥉' };
    const podColors = { 1: '#ffcf5c', 2: '#cfe0ff', 3: '#ff9d5c' };

    podiumOrder.forEach((p) => {
        const rank = p.rank;
        const color = p.rankColor || '#8ea0cc';
        const podColor = podColors[rank];
        const card = document.createElement('div');
        card.className = `podium-card rank-${rank}`;
        card.style.setProperty('--pod-color', podColor);
        card.innerHTML = `
            <div class="podium-medal">${medals[rank]}</div>
            <div class="podium-avatar" style="background:${escapeAttr(color)}">${initials(p.name)}</div>
            <div class="podium-name">${escapeHtml(p.name || 'Unknown')}</div>
            <div class="podium-rank-chip" style="background:${escapeAttr(color)}">${escapeHtml(p.rankName || 'Recruit')}</div>
            <div class="podium-stats">
                <div class="podium-stat kills"><strong>${p.kills ?? 0}</strong><span>Kills</span></div>
                <div class="podium-stat deaths"><strong>${p.deaths ?? 0}</strong><span>Deaths</span></div>
                <div class="podium-stat kd"><strong>${formatKd(p.kd)}</strong><span>K/D</span></div>
            </div>
            <div class="podium-step"></div>`;
        card.addEventListener('click', () => openProfileModal(p));
        lbPodium.appendChild(card);
    });

    if (rest.length) {
        lbTableHead.style.display = '';
        rest.forEach((p, i) => {
            const rank = p.rank || 0;
            const color = p.rankColor || '#8ea0cc';
            const row = document.createElement('div');
            row.className = 'lb-row';
            row.style.animationDelay = `${i * 45}ms`;
            row.innerHTML = `
                <span class="c-rank">#${rank}</span>
                <span class="c-player">
                    <span class="avatar-badge" style="background:${escapeAttr(color)}">${initials(p.name)}</span>
                    <span class="pplayer-text">
                        <span class="pname">${escapeHtml(p.name || 'Unknown Soldier')}</span>
                        <span class="rank-chip" style="background:${escapeAttr(color)}">${escapeHtml(p.rankName || 'Recruit')}</span>
                    </span>
                </span>
                <span class="c-num kills">${p.kills ?? 0}</span>
                <span class="c-num deaths">${p.deaths ?? 0}</span>
                <span class="c-num kd">${formatKd(p.kd)}</span>`;
            row.addEventListener('click', () => openProfileModal(p));
            leaderboardBody.appendChild(row);
        });
    }
}

function openProfileModal(p) {
    const color = p.rankColor || '#8ea0cc';
    const card = profileModal.querySelector('.modal-card');
    card.style.setProperty('--rank-color', color);

    const av = profileModal.querySelector('#mAvatar');
    av.textContent = initials(p.name);
    av.style.background = color;
    profileModal.querySelector('#mBadge').textContent = p.rankIcon || 'R';
    profileModal.querySelector('#mName').textContent = p.name || 'Unknown Soldier';
    profileModal.querySelector('#mRank').textContent = `${p.rankName || 'Recruit'} · ${p.rating ?? 0} RR`;
    profileModal.querySelector('#mKills').textContent = p.kills ?? 0;
    profileModal.querySelector('#mDeaths').textContent = p.deaths ?? 0;
    profileModal.querySelector('#mKd').textContent = formatKd(p.kd);
    profileModal.querySelector('#mBoardRank').textContent = `#${p.rank ?? 0}`;
    profileModal.querySelector('#mBarFill').style.width = `${p.rankProgress ?? 0}%`;
    profileModal.querySelector('#mProgressPct').textContent = `${p.rankProgress ?? 0}%`;
    profileModal.querySelector('#mNextLabel').textContent = p.nextRank ? `Next: ${p.nextRank}` : 'Max rank reached';

    profileModal.classList.add('show');
    profileModal.setAttribute('aria-hidden', 'false');
}

function closeProfileModal() {
    profileModal.classList.remove('show');
    profileModal.setAttribute('aria-hidden', 'true');
}

document.querySelector('#modalClose').addEventListener('click', closeProfileModal);
profileModal.addEventListener('click', (e) => { if (e.target === profileModal) closeProfileModal(); });

function rankLabel(rank) {
    if (rank === 1) return '🥇';
    if (rank === 2) return '🥈';
    if (rank === 3) return '🥉';
    return '#' + rank;
}

function formatKd(kd) {
    const n = Number(kd);
    return Number.isFinite(n) ? n.toFixed(2) : '0.00';
}

function initials(name) {
    const parts = String(name || '').trim().split(/\s+/).filter(Boolean);
    if (!parts.length) return '?';
    const chars = parts.length === 1 ? parts[0].slice(0, 2) : parts[0][0] + parts[1][0];
    return escapeHtml(chars.toUpperCase());
}

/* ---------------- helpers ---------------- */
function post(endpoint, body = {}) {
    fetch(`https://${RESOURCE}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body)
    }).catch(() => {});
}

function escapeHtml(str) {
    return String(str ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
function escapeAttr(str) { return escapeHtml(str); }
