function htmlForObject(obj) {
    return '<div class="objExample"><div>{</div>' + Object.keys(obj).map(key => {
        return `<div><div class="objKey">"${key}"</div>: <div class="objValue">"${obj[key]}"</div></div>`;
    }).join('') + '<div>}</div></div>';
}

function addConfettiRainOfLogo(glideLogo) {
    const img = glideLogo;
    const particleSize = 25;
    const particleCount = 60;
    const particleContainer = document.createElement('div');
    particleContainer.style.pointerEvents = 'none';
    particleContainer.style.position = 'fixed';
    particleContainer.style.top = '0';
    particleContainer.style.left = '0';
    particleContainer.style.bottom = '0';
    particleContainer.style.right = '0';
    particleContainer.style.overflow = 'hidden';

    document.body.appendChild(particleContainer);

    const particles = Array.from({ length: particleCount }).map(() => {
        const particle = document.createElement('div');
        particle.classList.add('particle');
        particle.style.width = `${particleSize}px`;
        particle.style.height = `${particleSize}px`;
        particle.style.position = 'absolute';
        particle.style.top = '0';
        particle.style.left = '0';
        particle.style.backgroundImage = `url(${img.src})`;
        particle.style.backgroundSize = 'cover';
        particle.style.backgroundRepeat = 'no-repeat';
        particle.style.backgroundPosition = 'center';
        particleContainer.appendChild(particle);
        return particle;
    });

    particles.forEach((particle) => {
        const randomX = Math.random() * window.innerWidth;
        const randomY = Math.random() * window.innerHeight - window.innerHeight;
        const randomRotation = Math.random() * 360;
        const randomOpacity = Math.random();
        const rotationSpeed = Math.random() * 4;
        const xMovement = Math.random() * 4 - 2;
        particle.opacity = randomOpacity;
        particle.speed = Math.random() * 6 + 3;
        particle.top = randomY;
        particle.style.top = `${randomY}px`;
        particle.left = randomX;
        particle.style.left = `${randomX}px`;
        particle.style.opacity = randomOpacity;
        particle.style.transform = `rotate(${randomRotation}deg)`;
        particle.rotation = randomRotation;
        particle.rotationSpeed = rotationSpeed * (Math.random() > 0.5 ? 1 : -1);
        particle.xMovement = xMovement;
    });

    let mousePos = { x: -1000, y: -1000 };
    document.addEventListener('mousemove', (event) => {
        mousePos = { x: event.clientX, y: event.clientY };
    });
    function animateParticles() {
        
        particles.forEach((particle) => {
            const distance = Math.sqrt(Math.pow(particle.left - mousePos.x, 2) + Math.pow(particle.top - mousePos.y, 2));
            
            particle.top = particle.top + particle.speed;
            particle.style.top = `${particle.top}px`;
            particle.left = particle.left + particle.xMovement;
            particle.style.left = `${particle.left}px`;
            const percentOpacity = Math.max(0, ((window.innerHeight*0.8) - particle.top)) / window.innerHeight;
            particle.style.opacity = percentOpacity * particle.opacity;
            particle.rotation = particle.rotation + particle.rotationSpeed;
            particle.style.transform = `rotate(${particle.rotation}deg)`;
            if (distance < 100) {
                const angle = Math.atan2(particle.top - mousePos.y, particle.left - mousePos.x);
                const force = (100 / distance) * 2;
                particle.opacity = Math.min(1, particle.opacity + 0.1);
                particle.xMovement += force * Math.cos(angle);
                particle.speed += force * Math.sin(angle);
            }
            
            if (particle.offsetTop > window.innerHeight || (particle.offsetTop < 0 && particle.speed < 0)) {
                const randomX = Math.random() * window.innerWidth;
                const randomY = Math.random() * window.innerHeight - window.innerHeight;
                const randomRotation = Math.random() * 360;
                const randomOpacity = Math.random();
                particle.speed = Math.random() * 6 + 3;
                particle.style.top = `${randomY}px`;
                particle.top = randomY;
                particle.style.left = `${randomX}px`;
                particle.style.opacity = randomOpacity;
                particle.style.transform = `rotate(${randomRotation}deg)`;
                particle.rotation = randomRotation;
                particle.opacity = randomOpacity;
                particle.left = randomX;
                particle.xMovement = Math.random() * 4 - 2;
            } 
        });

        setTimeout(() => {
            requestAnimationFrame(animateParticles);
        }, 1000 / 50);
        
    }

    requestAnimationFrame(animateParticles);
}