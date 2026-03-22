import { initializeApp } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-app.js";
import { getFirestore, collection, query, where, onSnapshot, doc, updateDoc } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-firestore.js";

// Firebase configuration based on your google-services.json
const firebaseConfig = {
    apiKey: "***REMOVED***",
    authDomain: "school-transport-system-6eb9f.firebaseapp.com",
    projectId: "school-transport-system-6eb9f",
    storageBucket: "school-transport-system-6eb9f.firebasestorage.app",
    messagingSenderId: "178202506405",
    appId: "1:178202506405:web:placeholder_if_needed"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

// DOM Elements
const loadingEl = document.getElementById('loading');
const gridPending = document.getElementById('grid-pending');
const gridApproved = document.getElementById('grid-approved');
const gridDeclined = document.getElementById('grid-declined');

const countPending = document.getElementById('count-pending');
const countApproved = document.getElementById('count-approved');
const countDeclined = document.getElementById('count-declined');

// Modal Elements
const modal = document.getElementById('imageModal');
const zoomedImage = document.getElementById('zoomedImage');
const closeModal = document.querySelector('.close-modal');

closeModal.onclick = () => {
    modal.classList.remove('show');
    setTimeout(() => { modal.style.display = 'none'; }, 300);
}

window.onclick = (e) => {
    if (e.target === modal) {
        modal.classList.remove('show');
        setTimeout(() => { modal.style.display = 'none'; }, 300);
    }
}

// Function to open image in modal
window.openModal = (src) => {
    modal.style.display = 'flex';
    // tiny delay required for transition to trigger
    setTimeout(() => {
        zoomedImage.src = src;
        modal.classList.add('show');
    }, 10);
};

// Function to update driver status
window.updateDriverStatus = async (uid, newStatus) => {
    try {
        const userRef = doc(db, 'users', uid);
        
        let approvedValue = false;
        if (newStatus === 'approved' || newStatus === true) {
            approvedValue = true;
        }

        await updateDoc(userRef, {
            status: newStatus,
            approved: approvedValue // updating 'approved' too, to ensure the mobile app login works flawlessly
        });
        
    } catch(err) {
        console.error("Error updating status:", err);
        alert("Failed to update status. Check console for details.");
    }
};

// Fetch Drivers
const driversQuery = query(collection(db, 'users'), where('userType', '==', 'driver'));

onSnapshot(driversQuery, (snapshot) => {
    loadingEl.style.display = 'none';
    
    // Clear grids
    gridPending.innerHTML = '';
    gridApproved.innerHTML = '';
    gridDeclined.innerHTML = '';
    
    let pCount = 0;
    let aCount = 0;
    let dCount = 0;

    snapshot.forEach((doc) => {
        const data = doc.data();
        const id = doc.id;
        
        // As you mentioned: "there is already a status field for the driver which is default false"
        // So status=false means pending. status='declined' means declined. status='approved' or true means approved.
        
        let currentState = 'pending';
        if (data.status === 'declined') {
            currentState = 'declined';
        } else if (data.status === 'approved' || data.status === true || data.approved === true) {
            currentState = 'approved';
        } else {
            currentState = 'pending'; // false or undefined
        }

        const dateStr = data.createdAt ? new Date(data.createdAt.toDate()).toLocaleDateString() : 'N/A';
        const imgFront = data.licenseFrontUrl || 'https://placehold.co/400x200?text=No+Front+Image';
        const imgBack = data.licenseBackUrl || 'https://placehold.co/400x200?text=No+Back+Image';
        
        const card = document.createElement('div');
        card.className = 'driver-card';
        card.innerHTML = `
            <div class="driver-header">
                <h4>${data.name || 'Unnamed Driver'}</h4>
            </div>
            <div class="driver-info">
                <p><i class="fa-solid fa-envelope"></i> ${data.email || 'No email'}</p>
                <p><i class="fa-solid fa-phone"></i> ${data.phone || 'No phone'}</p>
                <p><i class="fa-solid fa-calendar"></i> Joined: ${dateStr}</p>
            </div>
            <div class="license-images">
                <div>
                    <img src="${imgFront}" onclick="openModal('${imgFront}')" alt="License Front">
                    <span>Front</span>
                </div>
                <div>
                    <img src="${imgBack}" onclick="openModal('${imgBack}')" alt="License Back">
                    <span>Back</span>
                </div>
            </div>
            <div class="actions">
                ${currentState === 'pending' ? `
                    <button class="btn-approve" onclick="updateDriverStatus('${id}', 'approved')"><i class="fa-solid fa-check"></i> Approve</button>
                    <button class="btn-decline" onclick="updateDriverStatus('${id}', 'declined')"><i class="fa-solid fa-xmark"></i> Decline</button>
                ` : ''}
                ${currentState === 'approved' ? `
                    <button class="btn-decline" onclick="updateDriverStatus('${id}', 'declined')"><i class="fa-solid fa-ban"></i> Revoke & Decline</button>
                ` : ''}
                ${currentState === 'declined' ? `
                    <button class="btn-restore" onclick="updateDriverStatus('${id}', 'approved')"><i class="fa-solid fa-rotate-left"></i> Restore to Approved</button>
                ` : ''}
            </div>
        `;

        if (currentState === 'pending') {
            gridPending.appendChild(card);
            pCount++;
        } else if (currentState === 'approved') {
            gridApproved.appendChild(card);
            aCount++;
        } else if (currentState === 'declined') {
            gridDeclined.appendChild(card);
            dCount++;
        }
    });

    // Handle empty states
    if(pCount === 0) gridPending.innerHTML = '<p style="color:#777;">No pending approvals.</p>';
    if(aCount === 0) gridApproved.innerHTML = '<p style="color:#777;">No approved drivers.</p>';
    if(dCount === 0) gridDeclined.innerHTML = '<p style="color:#777;">No declined drivers.</p>';

    countPending.textContent = pCount;
    countApproved.textContent = aCount;
    countDeclined.textContent = dCount;
});

// Tab Switching Logic
const tabBtns = document.querySelectorAll('.tab-btn');
const tabContents = document.querySelectorAll('.tab-content');

tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
        // Remove active from all
        tabBtns.forEach(b => b.classList.remove('active'));
        tabContents.forEach(c => c.classList.remove('active'));
        
        // Add active to clicked
        btn.classList.add('active');
        document.getElementById('tab-' + btn.dataset.tab).classList.add('active');
    });
});
