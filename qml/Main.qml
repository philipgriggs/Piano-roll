import Felgo 3.0
import QtQuick 2.0
import QtMultimedia 5.12

App {
    id: app
    width: useVideo ? 1920 * 0.85 : 1600
    height: useVideo ? 1080 * 0.85 : 640

    property bool useVideo: true

    property int time: 0
    property int timerInterval
    property int numOctaves: 9
    property real shortestNote: 0.125 // the shortest note allowed is a demisemiquaver
    property var tempo: {
        "tempos": [],
        "currentIdx": 0,
    }
    property var notes: {
        "notes": []
    }
    property bool loaded
    property bool playing
    property real keyWidth: app.width / (88 * 7 / 12)
    property real keyHeight: keyWidth * 3

    property string handLeft: "left"
    property string handRight: "right"
    property string releaseLeft: "leftRelease"
    property string releaseRight: "rightRelease"

    Rectangle {
        anchors.fill: parent
        color: "white"
        focus: true
        Keys.onSpacePressed: {
            if (playing) {
                pause()
            } else {
                start()
            }
        }
    }

    Video {
        id: video
        visible: useVideo
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: -height * 0.05
        width: parent.width * 0.95
        height: parent.height
        source: "../assets/congratulations/congratulations.mov"
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: useVideo ? null : parent.verticalCenter
        anchors.bottom: useVideo ? parent.bottom : null
        anchors.bottomMargin: useVideo ? 0.1 * parent.height : 0
        Repeater {
            model: 88 + 9
            Item {
                id: keyContainer
                property int octave: Math.floor(index / 12)
                property bool blackKey: index%12 === 1 || index%12 === 3 || index%12 === 6 || index%12 === 8 || index%12 === 10
                property int key: 1 << index%12
                property bool pressed: ((notes[time][octave][app.handLeft] | notes[time][octave][app.handRight]) & keyContainer.key) > 0
                property string normalColor: blackKey ? "black" : "white"
                property string rightPressedColor: blackKey ? "#8bc1ff" : "#8bc1ff"
                property string leftPressedColor: blackKey ? "#d08585" : "#d08585"
                property string pressedColor: loaded && (notes[time][octave][app.handRight] & keyContainer.key) > 0 ? rightPressedColor : leftPressedColor
                width: blackKey ? 0.001 : keyWidth // if the width is 0, then it is not rendered at all, so make it 0.001
                height: blackKey ? keyHeight * 0.6 : keyHeight
                z: blackKey ? 2 : 1
                visible: index > 20
                Item {
                    id: keyClipper
                    width: keyContainer.blackKey ? keyWidth * 0.7 : keyWidth
                    height: parent.height
                    x: keyContainer.blackKey ? -width / 2 : 0
                    clip: true
                    Rectangle {
                        id: key
                        y: -height / 2
                        width: parent.width
                        height: keyContainer.height * 2
                        color: loaded && keyContainer.pressed ? keyContainer.pressedColor : keyContainer.normalColor
                        border.color: "black"
                        border.width: 1
                        radius: dp(5)
                    }
                    Rectangle {
                        id: topBorder
                        color: "black"
                        width: parent.width
                        height: 1
                    }
                    PolygonItem {
                        id: shadow
                        width: parent.width
                        height: parent.height
                        fill: true
                        color: keyContainer.blackKey ? "white" : "grey"
                        opacity: keyContainer.blackKey && !keyContainer.pressed ? 0.18 : 0
                        vertices: [Qt.point(shadow.width / 1.7 , shadow.height), Qt.point(shadow.width, shadow.height), Qt.point(shadow.width, 0), Qt.point(shadow.width * 0.8, 0)]
                    }
                }
            }
        }
    }

    Icon {
        visible: !useVideo
        icon: playing ? IconType.pause : IconType.play
        anchors.horizontalCenter: parent.horizontalCenter
        size: 50
        y: 20
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if(playing) {
                    pause()
                } else {
                    start()
                }
            }
        }
    }

    Component.onCompleted: {
        parseJson("../assets/congratulations/congratulations_right.json", "../assets/congratulations/congratulations_left.json")
        // example if there is one file only
//        parseJson("../assets/delusions/delusions_midi.json", "")
        loaded = true
    }

    MediaPlayer {
        id: track
        source: "../assets/congratulations/congratulations.mp3"
    }

    Timer {
        id: timer
        repeat: true
        interval: loaded ? 60 / tempo.tempos[tempo.currentIdx].bpm * shortestNote * 1000 : 0
        running: playing
        onTriggered: {
            time++
            if(tempo.currentIdx+1 < tempo.tempos.length && time > tempo.tempos[tempo.currentIdx+1].noteIdx) {
                tempo.currentIdx++
                tempoChanged()
            }
        }
    }

    function start() {
        playing = true
        track.play()
        video.play()
    }

    function pause() {
        playing = false
        track.pause()
        video.pause()
    }

    function parseJson(filePathRight, filePathLeft) {
        var fileRight = fileUtils.readFile(Qt.resolvedUrl(filePathRight))
        var fileLeft = fileUtils.readFile(Qt.resolvedUrl(filePathLeft))

        var midiRight = JSON.parse(fileRight)
        var midiLeft = {}
        if(filePathLeft !== "") {
            midiLeft = JSON.parse(fileLeft)
        }

        var ppq = midiRight.header.ppq

        // the number of ticks for one demisemiquaver - the smallest duration interval
        var quaverTicks = ppq * shortestNote

        var nNotes = midiRight.tracks[0].notes.length
        // assumes last note in the file is also the last note to release
        var totalDurationTicks = midiRight.tracks[0].notes[nNotes-1].ticks + midiRight.tracks[0].notes[nNotes-1].durationTicks
        var totalDurationQuavers = Math.ceil(totalDurationTicks/quaverTicks)

        // initialise notes array with an element for each quaver of the notes played
        // the first note should be at index 1, so that the first state is no notes played
        var notes = new Array(totalDurationQuavers + 1)
        for(var i = 0; i < notes.length; i++) {
            // each item in notes is one octave of notes, and 8 octaves for the whole range of notes
            notes[i] = new Array(numOctaves)
            for(var oct = 0; oct < numOctaves; oct++) {
                notes[i][oct] = {}
                notes[i][oct][app.handLeft] = 0
                notes[i][oct][app.handRight] = 0
                notes[i][oct][app.releaseLeft] = 0
                notes[i][oct][app.releaseRight] = 0
            }
        }

        notes = convertNotes(true, midiRight, notes, quaverTicks)
        notes = convertNotes(false, midiLeft, notes, quaverTicks)

        // get the tempo info
        var midiTempos = midiRight.header.tempos
        var convertedTempos = []
        for(i = 0; i < midiTempos.length; i++) {
            convertedTempos.push({
                                     "bpm": midiTempos[i].bpm,
                                     "noteIdx": Math.floor(midiTempos[i].ticks / quaverTicks)
                                 })
        }

        app.notes = notes
        app.tempo.tempos = convertedTempos
    }

    function convertNotes(right, midi, notes, quaverTicks) {
        if(midi.tracks) {
            var hand = app.handLeft
            var release = app.releaseLeft
            if(right) {
                hand = app.handRight
                release = app.releaseRight
            }

            for(var i = 0; i < midi.tracks[0].notes.length; i++) {
                var note = midi.tracks[0].notes[i]
                var startIdx = Math.round(note.ticks / quaverTicks) + 1
                var endIdx = startIdx + Math.ceil(note.durationTicks / quaverTicks)
                var octave = Math.floor(note.midi / 12)

                // "C" starts at 1 and not 0 (because no note is 0)
                var key = note.midi % 12

                for(var idx = startIdx; idx < endIdx; idx++) {
                    notes[idx][octave][hand] = notes[idx][octave][hand] | 1<<key

                    if (idx === endIdx-1) {
                        notes[idx][octave][release] = notes[idx][octave][release] | 1<<key
                    }
                }                
            }

            notes = deleteReleasedNotes(notes, right)
        }

        return notes
    }

    // if the same note is played twice in successive buckets, then it won't show as being released
    // so delete successive notes if they are marked with the 'release' flag
    function deleteReleasedNotes(notes, right) {
        var hand = app.handLeft
        var release = app.releaseLeft
        if(right) {
            hand = app.handRight
            release = app.releaseRight
        }
        for(var i = 1; i < notes.length - 1; i++) {            
            for(var oct = 0; oct < numOctaves; oct++) {
                // if it is the same note 3 buckets in a row and the middle one is a release, then delete the middle note
                // this is because we don't want to delete a note if it is only 1 interval in duration
                if((notes[i-1][oct][hand] & notes[i][oct][hand] & notes[i+1][oct][hand] & notes[i][oct][release]) > 0) {
                    notes[i][oct][hand] = notes[i][oct][hand] & ~notes[i][oct][release]
                }
            }
        }
        return notes
    }
}
