'use strict';

// =============================================
// NUI MESSAGE HANDLER
// =============================================
window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || !data.action) return;

    switch (data.action) {
        case 'openApplication':
            openApplication(data.jobs || []);
            break;
        case 'showApplications':
            showApplications(data.apps || []);
            break;
        case 'showTenants':
            showTenants(data.tenants || []);
            break;
        case 'close':
            closeAll();
            break;
    }
});

// =============================================
// APPLICATION FORM
// =============================================
function openApplication(jobs) {
    const select = document.getElementById('jobType');
    select.innerHTML = '<option value="">— Select —</option>';
    jobs.forEach(job => {
        const opt = document.createElement('option');
        opt.value = job.name;
        opt.textContent = job.label;
        select.appendChild(opt);
    });
    // Auto-fill today's date
    const today = new Date();
    const formatted = (today.getMonth()+1).toString().padStart(2,'0') + '/' +
                      today.getDate().toString().padStart(2,'0') + '/' +
                      today.getFullYear();
    document.getElementById('appDate').value = formatted;
    document.getElementById('app-modal').classList.remove('hidden');
}

function toggleKidsCount() {
    const hasKids = document.getElementById('hasKids').value === 'yes';
    document.getElementById('kidsCountGroup').style.display = hasKids ? 'flex' : 'none';
}

function toggleSnapInfo() {
    const checked = document.getElementById('applySnap').checked;
    document.getElementById('snapInfo').classList.toggle('hidden', !checked);
}

document.getElementById('applicationForm').addEventListener('submit', (e) => {
    e.preventDefault();

    const firstName = document.getElementById('firstName').value.trim();
    const lastName = document.getElementById('lastName').value.trim();
    const dateOfBirth = document.getElementById('dateOfBirth').value.trim();
    const currentAddress = document.getElementById('currentAddress').value.trim();
    const phoneNumber = document.getElementById('phoneNumber').value.trim();
    const applySnap = document.getElementById('applySnap').checked;
    const signature = document.getElementById('signature').value.trim();
    const appDate = document.getElementById('appDate').value;
    const jobType = document.getElementById('jobType').value;
    const income = parseInt(document.getElementById('income').value);
    const hasKids = document.getElementById('hasKids').value === 'yes';
    const numKids = hasKids ? parseInt(document.getElementById('numKids').value) || 1 : 0;
    const extraOccupants = document.getElementById('extraOccupants').value.trim();

    if (!firstName || !lastName) { showFormError('Please enter your full name.'); return; }
    if (!dateOfBirth) { showFormError('Please enter your date of birth.'); return; }
    if (!jobType) { showFormError('Please select your job type.'); return; }
    if (isNaN(income) || income < 0) { showFormError('Please enter a valid income.'); return; }
    if (!signature) { showFormError('Please sign the application at the bottom.'); return; }
    if (signature.toLowerCase() !== (firstName + ' ' + lastName).toLowerCase()) {
        showFormError('Signature must match your full name: ' + firstName + ' ' + lastName);
        return;
    }

    fetch(`https://${getResourceName()}/submitApplication`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ firstName, lastName, dateOfBirth, currentAddress, phoneNumber, appDate, jobType, income, hasKids, numKids, extraOccupants, applySnap, signature }),
    });

    document.getElementById('app-modal').classList.add('hidden');
    resetForm();
});

function showFormError(msg) {
    // Quick inline error - could expand later
    alert(msg);
}

function resetForm() {
    document.getElementById('applicationForm').reset();
    document.getElementById('kidsCountGroup').style.display = 'none';
    document.getElementById('snapInfo').classList.add('hidden');
}

// =============================================
// STAFF: APPLICATIONS
// =============================================
function showApplications(apps) {
    const container = document.getElementById('apps-list');
    container.innerHTML = '';

    if (!apps || apps.length === 0) {
        container.innerHTML = '<div class="empty-state">NO PENDING APPLICATIONS</div>';
    } else {
        apps.forEach(app => {
            const el = document.createElement('div');
            el.className = 'list-item';
            el.innerHTML = `
                <div class="list-item-header">
                    <span class="list-item-name">${escHtml(app.player_name)}</span>
                    <span class="badge badge-pending">PENDING #${app.id}</span>
                </div>
                <div class="list-item-details">
                    <div class="detail-field">
                        <label>JOB</label>
                        <span>${escHtml(app.job_type)}</span>
                    </div>
                    <div class="detail-field">
                        <label>INCOME</label>
                        <span>$${app.monthly_income}/mo</span>
                    </div>
                    <div class="detail-field">
                        <label>HAS KIDS</label>
                        <span>${app.has_kids ? 'Yes (' + app.num_kids + ')' : 'No'}</span>
                    </div>
                    <div class="detail-field" style="grid-column:1/-1">
                        <label>EXTRA OCCUPANTS</label>
                        <span>${app.extra_occupants ? escHtml(app.extra_occupants) : 'None'}</span>
                    </div>
                    <div class="detail-field" style="grid-column:1/-1">
                        <label>SUBMITTED</label>
                        <span>${app.submitted_at || 'Unknown'}</span>
                    </div>
                </div>
                <div class="list-item-actions">
                    <button class="btn-deny" onclick="denyApp(${app.id}, '${escHtml(app.player_name)}')">DENY</button>
                    <button class="btn-approve" onclick="approveApp(${app.id})">APPROVE</button>
                </div>
            `;
            container.appendChild(el);
        });
    }

    document.getElementById('apps-modal').classList.remove('hidden');
}

function approveApp(appId) {
    fetch(`https://${getResourceName()}/approveApplication`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ appId }),
    });
    // Remove from list
    document.getElementById('apps-modal').classList.add('hidden');
}

function denyApp(appId, name) {
    const reason = prompt(`Deny reason for ${name}?`, 'Does not meet income requirements');
    if (reason === null) return;
    fetch(`https://${getResourceName()}/denyApplication`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ appId, reason: reason || 'Does not meet requirements' }),
    });
    document.getElementById('apps-modal').classList.add('hidden');
}

// =============================================
// STAFF: TENANTS
// =============================================
function showTenants(tenants) {
    const container = document.getElementById('tenants-list');
    container.innerHTML = '';

    if (!tenants || tenants.length === 0) {
        container.innerHTML = '<div class="empty-state">NO ACTIVE TENANTS</div>';
    } else {
        tenants.forEach(t => {
            const warned = t.warned === 1;
            const el = document.createElement('div');
            el.className = 'list-item';
            el.innerHTML = `
                <div class="list-item-header">
                    <span class="list-item-name">${escHtml(t.tenant_name || 'Unknown')}</span>
                    <span class="badge ${warned ? 'badge-warned' : 'badge-ok'}">${warned ? '⚠ WARNED' : '✓ CURRENT'}</span>
                </div>
                <div class="list-item-details">
                    <div class="detail-field">
                        <label>UNIT</label>
                        <span>${escHtml(t.label || t.unit_id)}</span>
                    </div>
                    <div class="detail-field">
                        <label>RENT</label>
                        <span>$${t.rent_amount || '?'}/mo</span>
                    </div>
                    <div class="detail-field">
                        <label>SIZE</label>
                        <span>${(t.size || '').toUpperCase()}</span>
                    </div>
                    <div class="detail-field">
                        <label>LAST PAID</label>
                        <span>${t.last_paid ? t.last_paid.split('T')[0] : 'Never'}</span>
                    </div>
                    <div class="detail-field">
                        <label>DUE DATE</label>
                        <span>${t.due_date ? t.due_date.split('T')[0] : '—'}</span>
                    </div>
                    <div class="detail-field">
                        <label>CITIZEN ID</label>
                        <span>${escHtml(t.tenant_citizenid || '—')}</span>
                    </div>
                </div>
                <div class="list-item-actions">
                    <button class="btn-evict" onclick="evictTenant('${t.tenant_citizenid}', '${escHtml(t.tenant_name || '')}')">EVICT</button>
                </div>
            `;
            container.appendChild(el);
        });
    }

    document.getElementById('tenants-modal').classList.remove('hidden');
}

function evictTenant(citizenid, name) {
    if (!confirm(`Evict ${name || citizenid}? This will revoke their door access immediately.`)) return;
    fetch(`https://${getResourceName()}/evictTenant`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ citizenid }),
    });
    document.getElementById('tenants-modal').classList.add('hidden');
}

// =============================================
// CLOSE FUNCTIONS
// =============================================
function closeUI() {
    document.getElementById('app-modal').classList.add('hidden');
    resetForm();
    fetch(`https://${getResourceName()}/closeUI`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
    });
}

function closeApplications() {
    document.getElementById('apps-modal').classList.add('hidden');
    fetch(`https://${getResourceName()}/closeApplications`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
    });
}

function closeTenants() {
    document.getElementById('tenants-modal').classList.add('hidden');
    fetch(`https://${getResourceName()}/closeApplications`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
    });
}

function closeAll() {
    document.querySelectorAll('.modal').forEach(m => m.classList.add('hidden'));
    resetForm();
}

// =============================================
// UTILS
// =============================================
function escHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function getResourceName() {
    try {
        return window.getResourceName();
    } catch(e) {
        return 'gc-section8';
    }
}

// ESC key closes active modal
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeAll();
});
