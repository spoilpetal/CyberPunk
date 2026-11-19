import QtQuick 2.0
import QtQuick.Window 2.0
import SddmComponents 2.0

Rectangle {
    id: root

    width: Screen.width
    height: Screen.height

    color: "#050507"
    clip: true

    property color red: "#ff003c"
    property color yellow: "#fcee0a"
    property color cyan: "#00d9e8"
    property color pink: "#ff006e"
    property color white: "#f2f2f2"
    property color dark: "#08080a"

    property int sessionIndex: sessionModel.lastIndex

    TextConstants {
        id: textConstants
    }

    /* =========================
       PANTHER / NIGHT CITY ART
       ========================= */

    Image {
        id: artwork

        anchors.fill: parent

        source: "selected-background.png"
        fillMode: Image.PreserveAspectCrop
        smooth: true
    }

    /*
     * Darken only the extreme right edge slightly.
     * The artwork remains visible underneath.
     */
    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right

        width: parent.width * 0.42

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: "#00000000"
            }

            GradientStop {
                position: 0.28
                color: "#00000055"
            }

            GradientStop {
                position: 1.0
                color: "#00000099"
            }
        }
    }

    /* =========================
       DIGITAL NOISE
       ========================= */

    Repeater {
        model: 55

        Rectangle {
            width: (index % 5) + 1
            height: (index % 7) + 1

            x: (index * 137) % root.width
            y: (index * 83) % root.height

            color: index % 4 === 0 ? red :
                   index % 4 === 1 ? cyan :
                   index % 4 === 2 ? yellow :
                   pink

            opacity: 0.28
        }
    }

    /*
     * Thin scan lines
     */
    Repeater {
        model: Math.floor(root.height / 7)

        Rectangle {
            width: root.width
            height: 1

            y: index * 7

            color: "#ffffff"
            opacity: 0.025
        }
    }

    /* =========================
       TOP LEFT SECTOR MARKER
       ========================= */

    Text {
        x: 28
        y: 22

        text: "SECTOR 09"

        color: "#b8b8bd"

        font.pixelSize: 16
        font.bold: true
        font.letterSpacing: 2
    }

    Rectangle {
        x: 28
        y: 49

        width: 110
        height: 5

        color: "#7d7d85"
    }

    Repeater {
        model: 5

        Rectangle {
            x: 28 + index * 23
            y: 49

            width: 14
            height: 5

            rotation: -20

            color: dark
        }
    }

    /* =========================
       TOP RIGHT TERMINAL INFO
       ========================= */

    Text {
        anchors.top: parent.top
        anchors.right: parent.right

        anchors.topMargin: 22
        anchors.rightMargin: 30

        text: "NC-77 // SECURE TERMINAL"

        color: yellow

        font.pixelSize: 15
        font.bold: true
        font.letterSpacing: 2
    }

    /*
     * REAL CLOCK WITH SECONDS
     */
    Text {
        id: clock

        anchors.top: parent.top
        anchors.right: parent.right

        anchors.topMargin: 47
        anchors.rightMargin: 30

        color: white

        font.family: "Noto Sans Mono"
        font.pixelSize: 38
        font.bold: true
        font.letterSpacing: 2

        function updateClock() {
            var now = new Date()

            function pad(n) {
                return n < 10 ? "0" + n : n
            }

            text =
                pad(now.getHours()) + ":" +
                pad(now.getMinutes()) + ":" +
                pad(now.getSeconds())
        }

        Component.onCompleted: updateClock()

        Timer {
            interval: 1000
            running: true
            repeat: true

            onTriggered: clock.updateClock()
        }
    }

    Text {
        anchors.top: clock.bottom
        anchors.right: parent.right

        anchors.topMargin: 2
        anchors.rightMargin: 31

        text: Qt.formatDate(new Date(), "ddd, MMM dd, yyyy").toUpperCase()

        color: white

        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 2
    }

    /* =========================
       LOGIN PANEL SHADOWS
       ========================= */

    Rectangle {
        id: redShadow

        width: 455
        height: 525

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        anchors.rightMargin: 20

        x: parent.width - width - 14
        y: parent.height / 2 - height / 2 + 10

        color: red
        opacity: 0.38
    }

    Rectangle {
        width: 455
        height: 525

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        anchors.rightMargin: 28

        color: "#09090b"
        opacity: 0.96

        border.color: red
        border.width: 2

        /* -------------------------
           DISTRESSED BACKGROUND
           ------------------------- */

        Repeater {
            model: 45

            Rectangle {
                x: (index * 47) % parent.width
                y: (index * 79) % parent.height

                width: 8 + (index % 4) * 9
                height: index % 3 === 0 ? 2 : 1

                rotation: index * 17

                color:
                    index % 4 === 0 ? "#ffffff" :
                    index % 4 === 1 ? red :
                    index % 4 === 2 ? yellow :
                    cyan

                opacity: 0.10
            }
        }

        /* -------------------------
           PANEL HEADER
           ------------------------- */

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            height: 10

            color: red
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left

            anchors.topMargin: 10

            width: parent.width
            height: 3

            color: yellow
        }

        /* Hazard ribbon */

        Item {
            anchors.top: parent.top
            anchors.right: parent.right

            anchors.topMargin: 18
            anchors.rightMargin: -8

            width: 180
            height: 32

            rotation: -3

            Rectangle {
                anchors.fill: parent
                color: red
            }

            Repeater {
                model: 8

                Rectangle {
                    x: index * 28
                    y: -8

                    width: 12
                    height: 50

                    rotation: 35

                    color: dark
                }
            }
        }

        Column {
            id: form

            anchors.fill: parent

            anchors.leftMargin: 30
            anchors.rightMargin: 30

            anchors.topMargin: 35
            anchors.bottomMargin: 25

            spacing: 8

            Text {
                text: "ACCESS TERMINAL"

                color: yellow

                font.pixelSize: 24
                font.bold: true
                font.letterSpacing: 2
            }

            Text {
                text: "AUTHENTICATION REQUIRED"

                color: red

                font.pixelSize: 13
                font.bold: true
                font.letterSpacing: 2
            }

            Rectangle {
                width: parent.width
                height: 1

                color: "#55515a"
            }

            Text {
                text: "IDENTITY"

                color: "#c5c5ca"

                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 2
            }

            TextBox {
                id: name

                width: parent.width
                height: 46

                text: userModel.lastUser

                color: "#050507"
                textColor: white

                borderColor: "#77727c"
                focusColor: cyan

                font.pixelSize: 14

                KeyNavigation.tab: password

                Keys.onPressed: {
                    if (event.key === Qt.Key_Return ||
                        event.key === Qt.Key_Enter) {

                        sddm.login(
                            name.text,
                            password.text,
                            sessionIndex
                        )

                        event.accepted = true
                    }
                }
            }

            Text {
                text: "ACCESS KEY"

                color: "#c5c5ca"

                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 2
            }

            PasswordBox {
                id: password

                width: parent.width
                height: 46

                color: "#050507"
                textColor: white

                borderColor: "#77727c"
                focusColor: cyan

                font.pixelSize: 14

                KeyNavigation.backtab: name
                KeyNavigation.tab: sessionBox

                Keys.onPressed: {
                    if (event.key === Qt.Key_Return ||
                        event.key === Qt.Key_Enter) {

                        sddm.login(
                            name.text,
                            password.text,
                            sessionIndex
                        )

                        event.accepted = true
                    }
                }
            }

            Text {
                text: "SESSION"

                color: "#c5c5ca"

                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 2
            }

            /*
             * CUSTOM SESSION DROPDOWN
             *
             * This is kept above the lower controls using z.
             */
            Item {
                id: sessionArea

                width: parent.width
                height: 46

                z: 100

                property bool open: false

                Rectangle {
                    id: sessionBox

                    width: parent.width
                    height: 46

                    color: "#08090b"

                    border.color: sessionArea.open ? yellow : cyan
                    border.width: 2

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter

                        anchors.leftMargin: 14

                        text: sessionListView.currentItem ? sessionListView.currentItem.sessionName : "SELECT SESSION"

                        color: white

                        font.pixelSize: 14
                        font.bold: true
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        anchors.rightMargin: 15

                        text: sessionArea.open ? "▲" : "▼"

                        color: yellow

                        font.pixelSize: 16
                    }

                    MouseArea {
                        anchors.fill: parent

                        onClicked: {
                            sessionArea.open = !sessionArea.open
                        }
                    }
                }

                Rectangle {
                    id: dropdown

                    anchors.top: sessionBox.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right

                    height:
                        sessionArea.open
                        ? Math.min(sessionListView.count * 42, 170)
                        : 0

                    z: 1000

                    color: "#08090b"

                    border.color: yellow
                    border.width: sessionArea.open ? 2 : 0

                    clip: true

                    Behavior on height {
                        NumberAnimation {
                            duration: 120
                        }
                    }

                    ListView {
                        id: sessionListView

                       anchors.fill: parent
                       currentIndex: sessionIndex

                        model: sessionModel

                        delegate: Rectangle {
                            property string sessionName: model.name

                           width: dropdown.width
                            height: 42

                            color:
                                mouse.containsMouse
                                ? "#35101d"
                                : "#08090b"

                            Text {
                                anchors.fill: parent

                                anchors.leftMargin: 14
                                anchors.rightMargin: 14

                                verticalAlignment: Text.AlignVCenter

                                text: model.name

                                color:
                                    mouse.containsMouse
                                    ? yellow
                                    : white

                                font.pixelSize: 13
                            }

                            MouseArea {
                                id: mouse

                                anchors.fill: parent

                                hoverEnabled: true

                                onClicked: {
                                    sessionIndex = index
                                    sessionArea.open = false
                                }
                            }
                        }
                    }
                }
            }

            Text {
                id: errorMessage

                width: parent.width
                height: 28

                text: "SYSTEM READY. AWAITING CREDENTIALS..."

                color: red

                font.pixelSize: 11
                font.bold: true
            }

            Item {
                width: parent.width
                height: 54

                Row {
                    anchors.fill: parent

                    spacing: 9

                    Button {
                        id: loginButton

                        width: parent.width * 0.50
                        height: parent.height

                        text: "CONNECT"

                        color: red
                        activeColor: "#c00030"
                        pressedColor: "#700018"

                        textColor: white

                        font.pixelSize: 14
                        font.bold: true

                        onClicked: {
                            sddm.login(
                                name.text,
                                password.text,
                                sessionIndex
                            )
                        }
                    }

                    Button {
                        width: parent.width * 0.24
                        height: parent.height

                        text: "REBOOT"

                        color: "#151419"
                        activeColor: "#2b2520"
                        pressedColor: "#5c4510"

                        textColor: yellow

                        font.pixelSize: 10

                        onClicked: sddm.reboot()
                    }

                    Button {
                        width: parent.width * 0.22
                        height: parent.height

                        text: "OFF"

                        color: "#151419"
                        activeColor: "#35101d"
                        pressedColor: "#700018"

                        textColor: red

                        font.pixelSize: 11

                        onClicked: sddm.powerOff()
                    }
                }
            }

            Text {
                text: "SECURITY NODE // 09-77 // CONNECTION MONITORED"

                color: "#85818a"

                font.pixelSize: 8
                font.letterSpacing: 1
            }
        }
    }

    /* =========================
       SDDM EVENTS
       ========================= */

    Connections {
        target: sddm

        onLoginSucceeded: {
            errorMessage.color = cyan
            errorMessage.text = "ACCESS GRANTED // INITIALIZING SESSION"
        }

        onLoginFailed: {
            password.text = ""

            errorMessage.color = red
            errorMessage.text =
                "ACCESS DENIED // CHECK CREDENTIALS"
        }

        onInformationMessage: {
            errorMessage.color = yellow
            errorMessage.text = message
        }
    }

    Component.onCompleted: {
        if (name.text === "")
            name.focus = true
        else
            password.focus = true
    }
}
