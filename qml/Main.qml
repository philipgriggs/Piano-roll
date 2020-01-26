import Felgo 3.0
import QtQuick 2.0
import QtMultimedia 5.12

App {
    id: app
    width: 480
    height: 320

    property int time: 0
    property int timerInterval
    property int numOctaves: 9
    property real shortestNote: 0.5 // the shortest note allowed is a quaver
    property var tempo: {
        "tempos": [],
        "currentIdx": 0,
    }
    property var notes: {
        "notes": []
    }
    property bool loaded
    property bool playing
    property real keyWidth: (app.width - 10) / (88 - 44)
    property real keyHeight: keyWidth * 3

    Row {
        anchors.centerIn: parent
        Repeater {
            model: 89
            Item {
                property int octave: Math.floor(index / 12)
                property bool blackKey: index%12 === 1 || index%12 === 3 || index%12 === 6 || index%12 === 8 || index%12 === 10
                property var normalColor: blackKey ? "black" : "white"
                property var pressedColor: blackKey ? "#aaaaaa" : "grey"
                width: blackKey ? 0.001 : keyWidth // if the width is 0, then it is not rendered at all, so make it 0.001
                height: blackKey ? keyHeight * 0.6 : keyHeight
                z: blackKey ? 2 : 1
                visible: octave > 1
                Rectangle {
                    x: blackKey ? -width / 2 : 0
                    width: blackKey ? keyWidth * 0.7 : keyWidth
                    height: parent.height
                    color: loaded ? (notes[time][octave] & Math.pow(2, (index%12 + 1))) > 0 ? pressedColor : normalColor : normalColor
                    border.color: "black"
                    border.width: 1
                    radius: 1
                }
            }
        }
    }

    Icon {
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
        parseJson("../assets/delusions_midi.json")
        loaded = true
    }

    MediaPlayer {
        id: track
        source: "../assets/delusions.mp3"
    }

    Timer {
        id: timer
        repeat: true
        interval: loaded ? 60 / tempo.tempos[tempo.currentIdx].bpm * shortestNote * 1000 : 0
        running: playing
        onTriggered: {
            time++
            if(tempo.currentIdx+1 < tempo.tempos.length && time > tempo.tempos[tempo.currentIdx+1].noteIdx) {
                tempo.currentIdx += 1
                tempoChanged()
            }
        }
    }

    function start() {
        playing = true
        track.play()
    }

    function pause() {
        playing = false
        track.pause()
    }

    function parseJson(file) {
        var document = fileUtils.readFile(Qt.resolvedUrl(file))
        var midi = JSON.parse(document)

        var ppq = midi.header.ppq
        var bpm = 180

        // the number of ticks for one quaver - the smallest duration interval
        var quaverTicks = ppq * shortestNote

        var nNotes = midi.tracks[0].notes.length
        // assumes last note in the file is also the last note to release
        var totalDurationTicks = midi.tracks[0].notes[nNotes-1].ticks + midi.tracks[0].notes[nNotes-1].durationTicks
        var totalDurationQuavers = Math.ceil(totalDurationTicks/quaverTicks)

        // initialise notes array with an element for each quaver of the notes played
        // the first note should be at index 1, so that the first state is no notes played
        var notes = new Array(totalDurationQuavers + 1)
        for(var i = 0; i < notes.length; i++) {
            // each item in notes is one octave of notes, and 8 octaves for the whole range of notes
            notes[i] = new Array(numOctaves)
            for(var j = 0; j < numOctaves; j++) {
                notes[i][j] = 0
            }
        }

        for(i = 0; i < midi.tracks[0].notes.length; i++) {
            var note = midi.tracks[0].notes[i]
            var startIdx = Math.round(note.ticks / quaverTicks) + 1
            var endIdx = startIdx + Math.ceil(note.durationTicks / quaverTicks)
            var octave = Math.floor(note.midi / 12)
            // "C" starts at 1 and not 0 (because no note is 0)
            var key = note.midi % 12 + 1

            for(var idx = startIdx; idx < endIdx; idx++) {
                notes[idx][octave] = notes[idx][octave] | Math.pow(2, key)
            }
        }

        // get the tempo info
        var midiTempos = midi.header.tempos
        var convertedTempos = []
        for(i = 0; i < midiTempos.length; i++) {
            convertedTempos.push({
                                     "bpm": midiTempos[i].bpm,
                                     "noteIdx": Math.floor(midiTempos[i].ticks / quaverTicks)
                                 }
                                 )
        }

        app.notes = notes
        app.tempo.tempos = convertedTempos
    }
}
