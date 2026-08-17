<div class="screenshot-container">
  <img src="https://github.com/user-attachments/assets/f98adb1d-dfc3-4b4d-b701-52c3850687a1" alt="iPhone Screenshot 1" class="screenshot-img" />
  <img src="https://github.com/user-attachments/assets/91a1f964-1597-4324-96a9-89620100738b" alt="iPhone Screenshot 3" class="screenshot-img" />
</div>

<style>
  .screenshot-container {
    display: flex;
    flex-wrap: wrap; /* Keeps them responsive, but they will fit on one row on desktop now */
    justify-content: center;
    gap: 1.5rem;
    padding: 1rem;
    max-width: 1000px;
    margin: 0 auto;
  }

  .screenshot-img {
    /* Responsive sizing */
    width: 100%;
    
    /* CHANGE THIS VALUE TO REDUCE SIZE BY 50% (320px * 0.5 = 160px) */
    max-width: 160px; 
    
    height: auto;
    object-fit: contain;
    border-radius: 20px;
    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
  }
</style>
