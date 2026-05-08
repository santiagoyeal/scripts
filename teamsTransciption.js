(() => {
    console.clear();

    const vistos = new Set();
    const resultado = [];

    function obtenerTextoNodo(node) {
        return node.innerText
            ?.split('\n')
            .map(t => t.trim())
            .filter(Boolean)
            .join(' | ');
    }

    function escanear() {
        const elementos = document.querySelectorAll('div, span');

        elementos.forEach(el => {
            const texto = obtenerTextoNodo(el);

            if (
                texto &&
                texto.length > 20 &&
                !vistos.has(texto)
            ) {
                vistos.add(texto);
                resultado.push(texto);

                console.log(texto);
            }
        });
    }

    escanear();

    const observer = new MutationObserver(() => {
        escanear();
    });

    observer.observe(document.body, {
        childList: true,
        subtree: true
    });

    window.descargarTranscript = () => {
        const contenido = resultado.join('\n\n');

        const blob = new Blob([contenido], {
            type: 'text/plain'
        });

        const url = URL.createObjectURL(blob);

        const a = document.createElement('a');
        a.href = url;
        a.download = 'teams_transcripcion.txt';
        a.click();

        URL.revokeObjectURL(url);

        console.log('Descargado.');
    };

    console.log('Escuchando transcripción...');
    console.log('Haz scroll lentamente...');
})();
