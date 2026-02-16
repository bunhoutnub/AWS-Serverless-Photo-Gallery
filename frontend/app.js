// Photo Gallery Frontend Logic

// Configuration - UPDATE THIS WITH YOUR API GATEWAY URL AFTER DEPLOYMENT
const API_BASE_URL = 'https://njoff2es13.execute-api.us-east-1.amazonaws.com/prod';

// State
let allPhotos = [];
let filteredPhotos = [];
let currentPhotoId = null;

// Initialize app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    console.log('Photo Gallery initialized');
    
    // Set up event listeners
    setupEventListeners();
    
    // Load gallery on page load
    loadGallery();
});

function setupEventListeners() {
    // Upload form
    const uploadForm = document.getElementById('upload-form');
    const photoInput = document.getElementById('photo-input');
    const fileNameSpan = document.getElementById('file-name');
    
    photoInput.addEventListener('change', (e) => {
        const fileName = e.target.files[0]?.name || 'No file chosen';
        fileNameSpan.textContent = fileName;
    });
    
    uploadForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const file = photoInput.files[0];
        if (file) {
            await uploadPhoto(file);
        }
    });
    
    // Filter controls
    const tagSearch = document.getElementById('tag-search');
    const dateStart = document.getElementById('date-start');
    const dateEnd = document.getElementById('date-end');
    const clearFilters = document.getElementById('clear-filters');
    
    tagSearch.addEventListener('input', applyFilters);
    dateStart.addEventListener('change', applyFilters);
    dateEnd.addEventListener('change', applyFilters);
    
    clearFilters.addEventListener('click', () => {
        tagSearch.value = '';
        dateStart.value = '';
        dateEnd.value = '';
        applyFilters();
    });
    
    // Modal controls
    const modal = document.getElementById('photo-modal');
    const closeBtn = modal.querySelector('.close');
    const modalDelete = document.getElementById('modal-delete');
    
    closeBtn.addEventListener('click', closeModal);
    modalDelete.addEventListener('click', async () => {
        if (currentPhotoId && confirm('Are you sure you want to delete this photo?')) {
            await deletePhoto(currentPhotoId);
            closeModal();
        }
    });
    
    // Close modal when clicking outside
    modal.addEventListener('click', (e) => {
        if (e.target === modal) {
            closeModal();
        }
    });
}

// API Functions

async function uploadPhoto(file) {
    const statusDiv = document.getElementById('upload-status');
    
    try {
        statusDiv.className = 'status-message info';
        statusDiv.textContent = 'Uploading photo...';
        
        // Step 1: Get presigned URL from backend
        const response = await fetch(`${API_BASE_URL}/upload`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                filename: file.name,
                contentType: file.type
            })
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.error || 'Failed to get upload URL');
        }
        
        const data = await response.json();
        
        // Step 2: Upload file directly to S3 using presigned URL
        const formData = new FormData();
        Object.keys(data.fields).forEach(key => {
            formData.append(key, data.fields[key]);
        });
        formData.append('file', file);
        
        const uploadResponse = await fetch(data.uploadUrl, {
            method: 'POST',
            body: formData
        });
        
        if (!uploadResponse.ok) {
            throw new Error('Failed to upload photo to S3');
        }
        
        statusDiv.className = 'status-message success';
        statusDiv.textContent = 'Photo uploaded successfully! Processing thumbnail...';
        
        // Reset form
        document.getElementById('upload-form').reset();
        document.getElementById('file-name').textContent = 'No file chosen';
        
        // Reload gallery after a short delay to allow thumbnail processing
        setTimeout(() => {
            loadGallery();
            statusDiv.style.display = 'none';
        }, 3000);
        
    } catch (error) {
        console.error('Upload error:', error);
        statusDiv.className = 'status-message error';
        statusDiv.textContent = `Upload failed: ${error.message}`;
    }
}

async function loadGallery() {
    const galleryDiv = document.getElementById('gallery');
    const statusDiv = document.getElementById('gallery-status');
    
    try {
        statusDiv.className = 'status-message info';
        statusDiv.textContent = 'Loading photos...';
        
        const response = await fetch(`${API_BASE_URL}/photos`);
        
        if (!response.ok) {
            throw new Error('Failed to load photos');
        }
        
        const data = await response.json();
        allPhotos = data.photos || [];
        filteredPhotos = [...allPhotos];
        
        statusDiv.style.display = 'none';
        
        renderGallery();
        
    } catch (error) {
        console.error('Load gallery error:', error);
        statusDiv.className = 'status-message error';
        statusDiv.textContent = `Failed to load photos: ${error.message}`;
        galleryDiv.innerHTML = '';
    }
}

function renderGallery() {
    const galleryDiv = document.getElementById('gallery');
    
    if (filteredPhotos.length === 0) {
        galleryDiv.innerHTML = '<p style="text-align: center; color: #7f8c8d; grid-column: 1/-1;">No photos found. Upload your first photo!</p>';
        return;
    }
    
    galleryDiv.innerHTML = filteredPhotos.map(photo => `
        <div class="photo-card" data-photo-id="${photo.photoId}">
            <img src="${photo.thumbnailUrl}" alt="${photo.filename}" loading="lazy">
            <div class="photo-info">
                <h3>${photo.filename}</h3>
                <p>${formatDate(photo.uploadDate)}</p>
                <div class="photo-actions">
                    <button class="btn btn-primary btn-view" data-photo-id="${photo.photoId}">View</button>
                    <button class="btn btn-danger btn-delete" data-photo-id="${photo.photoId}">Delete</button>
                </div>
            </div>
        </div>
    `).join('');
    
    // Add event listeners to photo cards
    galleryDiv.querySelectorAll('.btn-view').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const photoId = btn.dataset.photoId;
            viewFullSize(photoId);
        });
    });
    
    galleryDiv.querySelectorAll('.btn-delete').forEach(btn => {
        btn.addEventListener('click', async (e) => {
            e.stopPropagation();
            const photoId = btn.dataset.photoId;
            if (confirm('Are you sure you want to delete this photo?')) {
                await deletePhoto(photoId);
            }
        });
    });
    
    // Click on card to view full size
    galleryDiv.querySelectorAll('.photo-card').forEach(card => {
        card.addEventListener('click', () => {
            const photoId = card.dataset.photoId;
            viewFullSize(photoId);
        });
    });
}

async function deletePhoto(photoId) {
    try {
        const response = await fetch(`${API_BASE_URL}/photos/${photoId}`, {
            method: 'DELETE'
        });
        
        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.error || 'Failed to delete photo');
        }
        
        // Remove from local state
        allPhotos = allPhotos.filter(p => p.photoId !== photoId);
        filteredPhotos = filteredPhotos.filter(p => p.photoId !== photoId);
        
        // Re-render gallery
        renderGallery();
        
        // Show success message
        const statusDiv = document.getElementById('gallery-status');
        statusDiv.className = 'status-message success';
        statusDiv.textContent = 'Photo deleted successfully';
        setTimeout(() => {
            statusDiv.style.display = 'none';
        }, 3000);
        
    } catch (error) {
        console.error('Delete error:', error);
        alert(`Failed to delete photo: ${error.message}`);
    }
}

function viewFullSize(photoId) {
    const photo = allPhotos.find(p => p.photoId === photoId);
    if (!photo) return;
    
    currentPhotoId = photoId;
    
    const modal = document.getElementById('photo-modal');
    const modalImage = document.getElementById('modal-image');
    const modalFilename = document.getElementById('modal-filename');
    const modalDate = document.getElementById('modal-date');
    const modalDimensions = document.getElementById('modal-dimensions');
    
    modalImage.src = photo.photoUrl;
    modalFilename.textContent = photo.filename;
    modalDate.textContent = `Uploaded: ${formatDate(photo.uploadDate)}`;
    
    if (photo.dimensions) {
        modalDimensions.textContent = `Dimensions: ${photo.dimensions.width} × ${photo.dimensions.height}px`;
    } else {
        modalDimensions.textContent = '';
    }
    
    modal.classList.add('active');
}

function closeModal() {
    const modal = document.getElementById('photo-modal');
    modal.classList.remove('active');
    currentPhotoId = null;
}

// Filter Functions

function applyFilters() {
    const tagSearch = document.getElementById('tag-search').value.toLowerCase().trim();
    const dateStart = document.getElementById('date-start').value;
    const dateEnd = document.getElementById('date-end').value;
    
    filteredPhotos = allPhotos.filter(photo => {
        // Tag filter
        if (tagSearch) {
            const matchesTag = photo.tags.some(tag => 
                tag.toLowerCase().includes(tagSearch)
            );
            if (!matchesTag) return false;
        }
        
        // Date filter
        if (dateStart || dateEnd) {
            const photoDate = new Date(photo.uploadDate).toISOString().split('T')[0];
            
            if (dateStart && photoDate < dateStart) return false;
            if (dateEnd && photoDate > dateEnd) return false;
        }
        
        return true;
    });
    
    renderGallery();
}

// Utility Functions

function formatDate(isoString) {
    const date = new Date(isoString);
    return date.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}
