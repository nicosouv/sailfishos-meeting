pragma Singleton
import QtQuick 2.0
import Sailfish.Silica 1.0

QtObject {
    property var userColorMap: ({})
    property var usedColors: []

    // Distance minimale entre deux couleurs (0-1, plus c'est haut plus elles doivent être différentes)
    property real minColorDistance: 0.25

    function getColorForUser(username) {
        if (username === "") return Theme.secondaryColor

        // Si l'utilisateur a déjà une couleur assignée, la retourner
        if (userColorMap[username] !== undefined) {
            return userColorMap[username]
        }

        // Générer une nouvelle couleur unique
        var color = generateUniqueColor()
        userColorMap[username] = color
        usedColors.push(hslFromColor(color))

        return color
    }

    function generateUniqueColor() {
        var maxAttempts = 100
        var attempts = 0

        while (attempts < maxAttempts) {
            // Générer une couleur aléatoire avec bonne saturation et luminosité
            var hue = Math.random()
            var saturation = 0.5 + Math.random() * 0.3  // 0.5-0.8
            var lightness = 0.45 + Math.random() * 0.2  // 0.45-0.65

            var newColor = {h: hue, s: saturation, l: lightness}

            // Vérifier si cette couleur est suffisamment différente des couleurs existantes
            if (isColorDistinct(newColor)) {
                return Qt.hsla(hue, saturation, lightness, 1.0)
            }

            attempts++
        }

        // Si on ne trouve pas de couleur unique après 100 tentatives,
        // retourner une couleur aléatoire quand même
        return Qt.hsla(Math.random(), 0.65, 0.55, 1.0)
    }

    function isColorDistinct(newColor) {
        // Si aucune couleur n'est utilisée, la nouvelle est forcément distincte
        if (usedColors.length === 0) {
            return true
        }

        // Vérifier la distance avec chaque couleur existante
        for (var i = 0; i < usedColors.length; i++) {
            var distance = colorDistance(newColor, usedColors[i])
            if (distance < minColorDistance) {
                return false
            }
        }

        return true
    }

    function colorDistance(color1, color2) {
        // Calculer la distance euclidienne dans l'espace HSL
        // La teinte (hue) est circulaire, donc on doit gérer le wrap-around
        var hueDiff = Math.abs(color1.h - color2.h)
        if (hueDiff > 0.5) {
            hueDiff = 1.0 - hueDiff
        }

        var satDiff = color1.s - color2.s
        var lightDiff = color1.l - color2.l

        // Distance pondérée : la teinte est plus importante pour la distinction
        return Math.sqrt(
            (hueDiff * 2.0) * (hueDiff * 2.0) +
            satDiff * satDiff +
            lightDiff * lightDiff
        )
    }

    function hslFromColor(color) {
        // Extraire les composantes HSL d'une couleur Qt
        return {
            h: color.hslHue,
            s: color.hslSaturation,
            l: color.hslLightness
        }
    }

    function resetColors() {
        userColorMap = {}
        usedColors = []
    }
}
