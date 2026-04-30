// ReadTimer hook
// Tracks how long the user has been reading the spark body.
// Unlocks the contribution form after the computed minimum read time.
//
// Minimum read time: max(30s, word_count / 200 * 60) seconds
// 200 words/min is average reading speed.
// We cap at 3 minutes to avoid frustrating engaged readers.

const ReadTimer = {
  mounted() {
    const wordCount = parseInt(this.el.dataset.wordCount || "0", 10);
    const minSeconds = parseInt(this.el.dataset.minSeconds || "30", 10);

    // Compute required read time
    const readingSeconds = Math.ceil((wordCount / 200) * 60);
    const required = Math.min(Math.max(minSeconds, readingSeconds), 180);

    let elapsed = 0;
    let unlocked = false;
    let visible = false;
    let interval = null;

    const form = document.getElementById("contribution-form-wrapper");
    const lock = document.getElementById("contribution-lock");
    const counter = document.getElementById("read-timer-count");

    if (!form || !lock) return;

    // Intersection observer — only count time when spark is visible
    const observer = new IntersectionObserver(
      (entries) => {
        visible = entries[0].isIntersecting;
        if (visible && !unlocked) {
          startTimer();
        } else {
          stopTimer();
        }
      },
      { threshold: 0.3 },
    );

    observer.observe(this.el);

    const startTimer = () => {
      if (interval) return;
      interval = setInterval(() => {
        elapsed++;
        const remaining = Math.max(0, required - elapsed);

        if (counter) {
          counter.textContent = remaining > 0 ? `${remaining}s` : "Ready";
        }

        if (elapsed >= required && !unlocked) {
          unlocked = true;
          unlock();
        }
      }, 1000);
    };

    const stopTimer = () => {
      clearInterval(interval);
      interval = null;
    };

    const unlock = () => {
      stopTimer();
      observer.disconnect();

      if (lock) lock.style.display = "none";
      if (form) form.style.display = "block";
    };

    // If already read enough (e.g. navigated back), unlock immediately
    if (elapsed >= required) unlock();
  },

  destroyed() {
    // cleanup handled by GC
  },
};

export default ReadTimer;
