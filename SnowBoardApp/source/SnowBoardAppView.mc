import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Attention;
import Toybox.Application.Storage;
import Toybox.System;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

class SnowBoardAppView extends WatchUi.View {
    private var _backgroundImage as BitmapResource?;
    private var _session as Session?;
    private var _isTracking as Boolean = false;
    private var _isPaused as Boolean = false;
    private var _gpsAccuracy as Number = 0;
    private var _pauseTimer as Number = 0;

    private var _runCount as Number = 0;
    private var _liftCount as Number = 0;
    private var _maxSpeedCurrentRun as Float = 0.0;
    private var _topSpeedEver as Float = 0.0;
    private var _totalDescend as Float = 0.0;
    private var _totalDistance as Float = 0.0;
    private var _lastAltitude as Float? = null;
    private var _isDescending as Boolean = false;

    function initialize() {
        View.initialize();
        if (Rez.Drawables has :BackgroundImage) {
            _backgroundImage = WatchUi.loadResource(Rez.Drawables.BackgroundImage) as BitmapResource;
        }
        
        var savedTopSpeed = Storage.getValue("topSpeedEver");
        if (savedTopSpeed != null) {
            _topSpeedEver = savedTopSpeed.toFloat();
        }
    }

    function onLayout(dc as Dc) as Void {}

    function isTracking() as Boolean { return _isTracking; }
    function hasActiveSession() as Boolean { return _session != null; }
    function getRunCount() as Number { return _runCount; }
    function getLiftCount() as Number { return _liftCount; }
    function getMaxSpeed() as Float { return _topSpeedEver; }
    function getTotalDescend() as Float { return _totalDescend; }
    function getTotalDistance() as Float { return _totalDistance; }

    function startTracking() as Void {
        if (Toybox has :ActivityRecording && _session == null) {
            _session = ActivityRecording.createSession({
                :name => "Snowboard",
                :sport => Activity.SPORT_SNOWBOARDING
            });
            _session.start();
            _isTracking = true;
            _runCount = 0; 
            vibrate(1);
        }
    }

    function toggleManualPause() as Void {
        if (_session != null) {
            if (_session.isRecording()) {
                _session.stop();
                _isPaused = true;
            } else {
                _session.start();
                _isPaused = false;
            }
            _pauseTimer = 5;
            vibrate(1);
        }
    }

    function stopAndSave() as Void {
        if (_session != null) {
            _session.stop();
            _session.save();
            _session = null;
            _isTracking = false;
        }
    }

    function stopAndDiscard() as Void {
        if (_session != null) {
            _session.stop();
            _session.discard();
            _session = null;
            _isTracking = false;
        }
    }

    function vibrate(count as Number) as Void {
        if (Attention has :vibrate) {
            var vibeData = [] as Array<Attention.VibeProfile>;
            for (var i = 0; i < count; i++) {
                vibeData.add(new Attention.VibeProfile(80, 300));
                if (i < count - 1) {
                    vibeData.add(new Attention.VibeProfile(0, 200));
                }
            }
            Attention.vibrate(vibeData);
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var info = Activity.getActivityInfo();

        if (!_isTracking) {
            drawStartScreen(dc, info);
        } else {
            drawMainScreen(dc, info);
        }
    }

    private function drawStartScreen(dc as Dc, info as Activity.Info?) as Void {
        if (_backgroundImage != null) {
            dc.drawBitmap(0, 0, _backgroundImage);
        }

        _gpsAccuracy = (info != null && info.currentLocationAccuracy != null) ? info.currentLocationAccuracy : 0;
        var ringColor = (_gpsAccuracy >= 3) ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;
        
        dc.setPenWidth(8);
        dc.setColor(ringColor, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(dc.getWidth()/2, dc.getHeight()/2, (dc.getWidth()/2) - 4);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var statusText = (_gpsAccuracy >= 3) ? "START-ra kész!" : "GPS keresése...";
        dc.drawText(dc.getWidth()/2, dc.getHeight() - 65, Graphics.FONT_XTINY, statusText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawMainScreen(dc as Dc, info as Activity.Info?) as Void {
        var speed = (info != null && info.currentSpeed != null) ? info.currentSpeed * 3.6 : 0.0;
        var altitude = (info != null && info.altitude != null) ? info.altitude : 0.0;
        var elapsedTime = (info != null && info.elapsedTime != null) ? info.elapsedTime / 1000 : 0;
        var heartRate = (info != null && info.currentHeartRate != null) ? info.currentHeartRate : "--";
        
        _totalDistance = (info != null && info.elapsedDistance != null) ? info.elapsedDistance / 1000.0 : 0.0;
        _totalDescend = (info != null && info.totalDescent != null) ? info.totalDescent.toFloat() : 0.0;

        if (_lastAltitude != null) {
            var diff = altitude - _lastAltitude;
            if (!_isDescending && diff < -1.5 && speed > 7.0) { 
                _isDescending = true;
                _runCount++; 
                _maxSpeedCurrentRun = 0.0;
                vibrate(1);
            } 
            else if (_isDescending && diff > 2.5) { 
                _isDescending = false;
                _liftCount++;
                vibrate(2);
            }
        }
        _lastAltitude = altitude.toFloat();

        if (_isDescending) {
            if (speed > _maxSpeedCurrentRun) { _maxSpeedCurrentRun = speed.toFloat(); }
            if (speed > _topSpeedEver) {
                _topSpeedEver = speed.toFloat();
                Storage.setValue("topSpeedEver", _topSpeedEver);
                vibrate(3);
            }
        }

        if (_session != null) {
            if (!_isPaused && speed < 1.5 && _session.isRecording()) { 
                _session.stop();
                _isPaused = true; _pauseTimer = 5; vibrate(1); 
            } else if (_isPaused && speed > 4.0 && !_session.isRecording()) { 
                _session.start();
                _isPaused = false; _pauseTimer = 5; vibrate(1); 
            }
        }

        var w = dc.getWidth();
        var h = dc.getHeight();

        // --- DINAMIKUS FÁZIS JELZÉS ---
        var phaseColor = _isDescending ? Graphics.COLOR_GREEN : Graphics.COLOR_BLUE;
        dc.setColor(phaseColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, h*0.18);

        // Pontos idő lekérése
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var timeStr = Lang.format("$1$:$2$", [now.hour.format("%02d"), now.min.format("%02d")]);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w*0.15, 10, Graphics.FONT_XTINY, timeStr, Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(w*0.85, 10, Graphics.FONT_XTINY, "HR: " + heartRate, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(w/2, 30, Graphics.FONT_XTINY, formatTime(elapsedTime.toNumber()), Graphics.TEXT_JUSTIFY_CENTER);

        // Adatválasztó vonalak
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, h*0.32, w, h*0.32);
        dc.drawLine(0, h*0.68, w, h*0.68);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, 45, Graphics.FONT_SMALL, "RUNS: " + _runCount + " | LIFTS: " + _liftCount, Graphics.TEXT_JUSTIFY_CENTER);

        // Sebesség
        dc.drawText(w/2, h/2 - 40, Graphics.FONT_NUMBER_THAI_HOT, speed.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h/2 + 25, Graphics.FONT_TINY, "TOP: " + _topSpeedEver.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);

        // Alsó sáv
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w*0.22, h*0.70, Graphics.FONT_XTINY, "DESC", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w*0.50, h*0.70, Graphics.FONT_XTINY, "KM", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w*0.78, h*0.70, Graphics.FONT_XTINY, "MAX R", Graphics.TEXT_JUSTIFY_CENTER);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w*0.22, h*0.80, Graphics.FONT_TINY, _totalDescend.format("%d") + "m", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w*0.50, h*0.80, Graphics.FONT_TINY, _totalDistance.format("%.2f"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w*0.78, h*0.80, Graphics.FONT_TINY, _maxSpeedCurrentRun.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);

        if (_pauseTimer > 0) {
            drawOverlayIcon(dc);
            _pauseTimer--;
        }
    }

    private function formatTime(seconds as Number) as String {
        var hh = seconds / 3600;
        var mm = (seconds % 3600) / 60;
        var ss = seconds % 60;
        return (hh > 0 ? hh.format("%d") + ":" : "") + mm.format("%02d") + ":" + ss.format("%02d");
    }

    private function drawOverlayIcon(dc as Dc) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        if (_isPaused) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
            dc.fillRectangle(cx - 15, cy - 20, 10, 40);
            dc.fillRectangle(cx + 5, cy - 20, 10, 40);
        } else {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);
            var pts = [[cx - 15, cy - 20], [cx - 15, cy + 20], [cx + 20, cy]] as Array;
            dc.fillPolygon(pts);
        }
    }
}