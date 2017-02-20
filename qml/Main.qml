import QtQuick 2.6
import QtQuick.Controls 1.4
import QtQuick.Layouts 1.1
import QtQuick.Controls.Styles 1.4
import QtQuick.Dialogs 1.2

ApplicationWindow {
    id: appWindow
    width: 300
    height: 400
    minimumHeight: 400
    minimumWidth: 300
    visible: true
    title: qsTr("Yubico Authenticator")
    property var device: yk
    property int expiration: 0
    property var credentials: device.credentials
    property bool validated: device.validated
    property bool hasDevice: device.hasDevice
    property var hotpCoolDowns: []
    property var totpCoolDowns: []

    SystemPalette { id: palette }

    /*******

        Main menu bar

    *******/

    menuBar: MenuBar {

        Menu {
            title: qsTr("File")
            MenuItem {
                text: qsTr('Add credential...')
                onTriggered: {
                    addCredential.clear();
                    addCredential.open()
                }
                shortcut: StandardKey.New
            }
            MenuItem {
                text: qsTr('Set password...')
                onTriggered: setPassword.open()
            }
            MenuItem {
                text: qsTr('Reset...')
                onTriggered: reset.open()
            }
            MenuItem {
                text: qsTr('Settings')
                onTriggered: settings.open()
            }
            MenuItem {
                text: qsTr("Exit")
                onTriggered: Qt.quit()
                shortcut: StandardKey.Quit
            }
        }

        Menu {
            title: qsTr("Help")
            MenuItem {
                text: qsTr("About Yubico Authenticator")
                onTriggered: aboutPage.show()
            }
        }
    }

    AboutPage {
        id: aboutPage
    }

    AddCredential {
        id: addCredential
    }

    /*******

        Settings dialog

    *******/

    Settings {
        id: settings
    }


    /*******

        Set password dialog

    *******/

    SetPassword {
        id: setPassword
        onAccepted: {
            if (setPassword.newPassword !== setPassword.confirmPassword) {
                noMatch.open()
            } else {
                if (setPassword.newPassword != "") {
                    device.setPassword(setPassword.newPassword)
                } else {
                    device.setPassword(null)
                }
                passwordUpdated.open()
            }
        }
    }

    MessageDialog {
        id: noMatch
        icon: StandardIcon.Critical
        title: qsTr("Passwords does not match")
        text: qsTr("Password confirmation does not match password.")
        standardButtons: StandardButton.Ok
        onAccepted: setPassword.open()
    }

    MessageDialog {
        id: passwordUpdated
        icon: StandardIcon.Information
        title: qsTr("Password set")
        text: qsTr("A new password has been set.")
        standardButtons: StandardButton.Ok
    }

    /*******

        Reset dialog

    *******/

    MessageDialog {
        id: reset
        icon: StandardIcon.Critical
        title: qsTr("Reset OATH functionality")
        text: qsTr("This will delete all OATH credentials stored on the device, and reset the password. This action cannot be undone. Are you sure you want to reset the device?")
        standardButtons: StandardButton.Ok | StandardButton.Cancel
        onAccepted: {
            device.reset()
            device.refreshCredentials()
        }
    }


    /*******

        Device - prompt for password if needed

    *******/

    onHasDeviceChanged: {
        if (device.hasDevice) {
            device.promptOrSkip(passwordPrompt)
        } else {
            passwordPrompt.close()
            addCredential.close()
        }
    }

    PasswordPrompt {
        id: passwordPrompt
    }

    onCredentialsChanged: {
        updateExpiration()
        hotpCoolDowns = []
        totpCoolDowns = []
        hotpTouchTimer.stop()
        hotpCoolDownTimer.stop()
        touchYourYubikey.close()
    }

    // @disable-check M301
    YubiKey {
        id: yk
        onError: {
            console.log(error)
        }
        onWrongPassword: {
            passwordPrompt.open()
        }
    }

    Text {
        visible: !device.hasDevice
        id: noLoadedDeviceMessage
        text: if (device.nDevices == 0) {
                  qsTr("No YubiKey detected")
              } else if (device.nDevices == 1) {
                  qsTr("Connecting to YubiKey...")
              } else {
                  qsTr("Multiple YubiKeys detected!")
              }
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
    }


    /*******

        Clipboard

    *******/

    TextEdit {
        id: clipboard
        visible: false
        function setClipboard(value) {
            text = value
            selectAll()
            copy()
        }
    }


    /*******

        Right click menu for credentials

    *******/

    Menu {
        id: credentialMenu
        MenuItem {
            text: qsTr('Copy')
            shortcut: StandardKey.Copy
            onTriggered: {
                if (repeater.selected != null) {
                    clipboard.setClipboard(repeater.selected.code)
                }
            }
        }
        MenuItem {
            visible: allowManualGenerate(repeater.selected)
            enabled: allowManualGenerate(repeater.selected) && !isInCoolDown(repeater.selected.name)
            text: qsTr('Generate code')
            shortcut: "Space"
            onTriggered: {
                if (!isInCoolDown(repeater.selected.name)) {
                    calculateCredential(repeater.selected)
                    if (repeater.selected.oath_type === "hotp") {
                        hotpCoolDowns.push(repeater.selected.name)
                        hotpCoolDownTimer.restart()
                    } else if(repeater.selected.touch) {
                       totpCoolDowns.push(repeater.selected.name)
                    }
                }
            }
        }
        MenuItem {
            text: qsTr('Delete')
            shortcut: StandardKey.Delete
            onTriggered: confirmDeleteCredential.open()
        }
    }

    function allowManualGenerate(cred) {
        return cred != null && (cred.oath_type === "hotp" || repeater.selected.touch)
    }

    MessageDialog {
        id: confirmDeleteCredential
        icon: StandardIcon.Warning
        title: qsTr("Delete credential?")
        text: qsTr("Are you sure you want to delete the credential?")
        standardButtons: StandardButton.Ok | StandardButton.Cancel
        onAccepted: {
            device.deleteCredential(repeater.selected)
            device.refreshCredentials()
        }
    }

    MessageDialog {
        id: touchYourYubikey
        icon: StandardIcon.Information
        title: qsTr("Touch your YubiKey")
        text: qsTr("Touch your YubiKey to generate the code.")
        standardButtons: StandardButton.NoButton
    }


    /*******

        Arrow key navigation

    *******/


    Item {
        id: arrowKeys
        focus: true
        Keys.onUpPressed: {
            if (repeater.selectedIndex == null) {
                repeater.selected = repeater.model[repeater.model.length - 1]
                repeater.selectedIndex = repeater.model.length - 1
            } else if (repeater.selectedIndex > 0) {
                repeater.selected = repeater.model[repeater.selectedIndex - 1]
                repeater.selectedIndex = repeater.selectedIndex - 1
            }
        }
        Keys.onDownPressed: {
            if (repeater.selectedIndex == null) {
                repeater.selected = repeater.model[0]
                repeater.selectedIndex = 0
            } else if (repeater.selectedIndex < repeater.model.length - 1) {
                repeater.selected = repeater.model[repeater.selectedIndex + 1]
                repeater.selectedIndex = repeater.selectedIndex + 1
            }
        }
    }


    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        /*******

            Time left bar

        *******/

        ProgressBar {
            id: progressBar
            visible: hasDevice
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.maximumHeight: 10
            Layout.minimumHeight: 10
            Layout.minimumWidth: 300
            Layout.fillWidth: true
            maximumValue: 30
            minimumValue: 0

            style: ProgressBarStyle {
                progress: Rectangle {
                    color: "#9aca3c"
                }

                background: Rectangle {
                    color: palette.mid
                }
            }
        }

        ScrollView {
            id: scrollView
            Layout.fillHeight: true
            Layout.fillWidth: true

            ColumnLayout {
                width: scrollView.viewport.width
                id: credentialsColumn
                spacing: 0
                visible: device.hasDevice
                anchors.right: appWindow.right
                anchors.left: appWindow.left
                anchors.top: appWindow.top

                /*******

                    Credential items

                *******/

                Repeater {
                    id: repeater
                    model: filteredCredentials(credentials, search.text)
                    property var selected
                    property var selectedIndex

                    Rectangle {
                        id: credentialRectangle
                        focus: true
                        color: {
                            if (repeater.selected != null) {
                                if (repeater.selected.name == modelData.name) {
                                    return palette.dark
                                }
                            }
                            if (index % 2 == 0) {
                                return "#00000000"
                            }
                            return palette.alternateBase
                        }
                        Layout.fillWidth: true
                        Layout.minimumHeight: 70
                        Layout.alignment: Qt.AlignTop

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                arrowKeys.forceActiveFocus()
                                if (mouse.button & Qt.LeftButton) {
                                    if (repeater.selected != null
                                            && repeater.selected.name == modelData.name) {
                                        repeater.selected = null
                                        repeater.selectedIndex = null
                                    } else {
                                        repeater.selected = modelData
                                        repeater.selectedIndex = index
                                    }
                                }
                                if (mouse.button & Qt.RightButton) {
                                    repeater.selected = modelData
                                    repeater.selectedIndex = index
                                    credentialMenu.popup()
                                }
                            }
                            acceptedButtons: Qt.RightButton | Qt.LeftButton
                        }

                        ColumnLayout {
                            anchors.leftMargin: 10
                            spacing: -15
                            anchors.fill: parent
                            Text {
                                visible: hasIssuer(modelData.name)
                                text: qsTr('') + parseIssuer(modelData.name)
                                font.pointSize: 13
                            }
                            Text {
                                opacity: isInCoolDown(modelData.name) ? 0.6 : 1
                                visible: modelData.code != null
                                text: qsTr('') + modelData.code
                                font.family: "Verdana"
                                font.pointSize: 22
                            }
                            Text {
                                text: hasIssuer(
                                          modelData.name) ? qsTr(
                                                                '') + parseName(
                                                                modelData.name) : modelData.name
                                font.pointSize: 13
                            }
                        }
                    }
                }
            }
        }

        /*******

            Search field

        *******/

        TextField {
            id: search
            visible: hasDevice
            placeholderText: 'Search...'
            Layout.fillWidth: true
        }
    }


    /*******

        Timers

    *******/

    Timer {
        id: ykTimer
        triggeredOnStart: true
        interval: 500
        repeat: true
        running: true
        onTriggered: device.refresh()
    }

    Timer {
        id: progressBarTimer
        interval: 100
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            var timeLeft = expiration - (Date.now() / 1000)
            if (timeLeft <= 0 && progressBar.value > 0) {
                device.refresh()
                totpCoolDowns = []
            }
            progressBar.value = timeLeft
        }
    }

    Timer {
        id: hotpCoolDownTimer
        interval: 5000
        onTriggered: hotpCoolDowns = []
    }

    Timer {
        id: hotpTouchTimer
        interval: 500
        onTriggered: touchYourYubikey.open()
    }


    /*******

        Utility functions

    *******/

    function filteredCredentials(creds, search) {
        var result = []
        if (creds != null) {
            for (var i = 0; i < creds.length; i++) {
                var cred = creds[i]
                if (cred.name.toLowerCase().indexOf(search.toLowerCase(
                                                        )) !== -1) {
                    result.push(creds[i])
                }
            }
        }
        return result
    }

    function isInCoolDown(name) {
        return hotpCoolDowns.indexOf(name) !== -1 || totpCoolDowns.indexOf(name) !== -1
    }
    function hasIssuer(name) {
        return name.indexOf(':') !== -1
    }
    function parseName(name) {
        return name.split(":").slice(1).join(":")
    }
    function parseIssuer(name) {
        return name.split(":", 1)
    }

    function calculateCredential(credential) {

        device.calculate(credential)
        if (credential.oath_type === 'hotp') {
            hotpTouchTimer.restart()
        }
        if (credential.touch) {
            touchYourYubikey.open()
        }
    }

    function updateExpiration() {
        var maxExpiration = 0
        if (credentials !== null) {
            for (var i = 0; i < credentials.length; i++) {
                var exp = credentials[i].expiration
                if (exp !== null && exp > maxExpiration) {
                    maxExpiration = exp
                }
            }
            expiration = maxExpiration
        }
    }
}
