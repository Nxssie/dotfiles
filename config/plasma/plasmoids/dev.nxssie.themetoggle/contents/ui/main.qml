import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    // The active color scheme decides the tooltip, so the widget never needs its own state
    readonly property bool dark: Kirigami.Theme.backgroundColor.hslLightness < 0.5

    // Like Plasma's own one-click widgets (show desktop...): the button is the
    // full representation and is shown inline in the panel
    preferredRepresentation: fullRepresentation
    toolTipMainText: dark ? "Dark theme" : "Light theme"
    toolTipSubText: "Click to switch to the " + (dark ? "light" : "dark") + " theme"

    P5Support.DataSource {
        id: runner
        engine: "executable"
        connectedSources: []
        onNewData: (source, data) => disconnectSource(source)
    }

    fullRepresentation: PlasmaComponents3.ToolButton {
        display: QQC2.AbstractButton.IconOnly
        icon.name: "contrast"
        onClicked: runner.connectSource("\"$HOME/.local/bin/theme-toggle\"")
    }
}
