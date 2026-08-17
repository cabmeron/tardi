<div class="screenshot-container">
  <img src="https://github.com/user-attachments/assets/f98adb1d-dfc3-4b4d-b701-52c3850687a1" alt="iPhone Screenshot 1" class="screenshot-img" />
  <img src="https://github.com/user-attachments/assets/5f02594a-e2bb-4347-9fb6-97d265b0d4bd" alt="iPhone Screenshot 2" class="screenshot-img" />
</div>

<style>
  .screenshot-container {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: 1.5rem;
    padding: 1rem;
    max-width: 1000px;
    margin: 0 auto;
  }

  .screenshot-img {
    /* Responsive sizing based on iPhone aspect ratio (~1:2.1) */
    width: 100%;
    max-width: 320px; /* Adjusts desktop size so it isn't overly massive */
    height: auto;
    object-fit: contain;
    border-radius: 20px; /* Optional: adds subtle device-like rounded corners */
    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1); /* Optional: soft elevation shadow */
  }
</style>
