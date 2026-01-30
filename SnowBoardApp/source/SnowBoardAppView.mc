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
import Toybox.Position;

class SnowBoardAppView extends WatchUi.View {

    private var _backgroundImage as BitmapResource?;
    private var _session as Session? = null;
    private var _isTracking as Boolean = false;
    private var _isPaused as Boolean = false;
    private var _gpsAccuracy as Number = 0;
    private var _gpsVibrated as Boolean = false;
    private var _pauseTimer as Number = 0;
    private var _currentScreen as Number = 1;
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
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
    }

    function onPosition(info as Position.Info) as Void {
        _gpsAccuracy = info.accuracy;
        if (!_gpsVibrated && _gpsAccuracy >= 3) {
            vibrate(2);
            _gpsVibrated = true;
        } else if (_gpsAccuracy < 3) {
            _gpsVibrated = false;
        }
        WatchUi.requestUpdate();
    }

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
            _pauseTimer = 2;
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

    // Függvény a képernyő váltásához (a Delegate fogja hívni)
    function nextScreen() as Void {
        _currentScreen++;
        if (_currentScreen > 3) { _currentScreen = 1; }
        vibrate(1);
        WatchUi.requestUpdate();
    }

    function prevScreen() as Void {
        _currentScreen--;
        if (_currentScreen < 1) { _currentScreen = 3; }
        vibrate(1);
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var info = Activity.getActivityInfo();
        
        if (!_isTracking) {
            drawStartScreen(dc, info);
            return;
        }

        // Képernyő választó logika
        if (_currentScreen == 1) {
            drawMainScreen(dc, info);
        } else if (_currentScreen == 2) {
            drawElevationScreen(dc, info);
        } else if (_currentScreen == 3) {
            drawHealthScreen(dc, info);
        }
    }

    // --- 2. KÉPERNYŐ: ELEVATION & LIFTS ---
    private function drawElevationScreen(dc as Dc, info as Activity.Info?) as Void {
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();
        var totalAscent = (info != null && info.totalAscent != null) ? info.totalAscent : 0;
        
        drawCommonHeader(dc);
        
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.30, Graphics.FONT_XTINY, "TOTAL ASCENT", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.45, Graphics.FONT_NUMBER_MEDIUM, totalAscent.toString() + " m", Graphics.TEXT_JUSTIFY_CENTER);
        
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.65, Graphics.FONT_XTINY, "LIFTS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.75, Graphics.FONT_NUMBER_MILD, _liftCount.toString(), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // --- 3. KÉPERNYŐ: HR & CALORIES ---
    private function drawHealthScreen(dc as Dc, info as Activity.Info?) as Void {
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();
        var hr = (info != null && info.currentHeartRate != null) ? info.currentHeartRate : "--";
        var calories = (info != null && info.calories != null) ? info.calories : 0;

        drawCommonHeader(dc);

        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.30, Graphics.FONT_XTINY, "HEART RATE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.45, Graphics.FONT_NUMBER_MEDIUM, hr.toString(), Graphics.TEXT_JUSTIFY_CENTER);
        
        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.65, Graphics.FONT_XTINY, "CALORIES", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.75, Graphics.FONT_NUMBER_MILD, calories.toString(), Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Segédfüggvény az óra és akksi rajzolásához minden oldalon
    private function drawCommonHeader(dc as Dc) as Void {
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.06).toNumber(), Graphics.FONT_MEDIUM, Lang.format("$1$:$2$", [now.hour.format("%02d"), now.min.format("%02d")]), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.92).toNumber(), Graphics.FONT_TINY, System.getSystemStats().battery.format("%d") + "%", Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawStartScreen(dc as Dc, info as Activity.Info?) as Void {
        if (_backgroundImage != null) { dc.drawBitmap(0, 0, _backgroundImage); }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth()/2, (dc.getHeight() * 0.88).toNumber(), Graphics.FONT_XTINY, "v1.2", Graphics.TEXT_JUSTIFY_CENTER);
        
        var ringColor = (_gpsAccuracy >= 3) ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;
        dc.setPenWidth(10); 
        dc.setColor(ringColor, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(dc.getWidth()/2, dc.getHeight()/2, (dc.getWidth()/2) - 6);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var statusText = (_gpsAccuracy >= 3) ? "START-ra kész!" : "GPS keresése...";
        dc.drawText(dc.getWidth()/2, (dc.getHeight() * 0.72).toNumber(), Graphics.FONT_XTINY, statusText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawMainScreen(dc as Dc, info as Activity.Info?) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;

        var speed = (info != null && info.currentSpeed != null) ? info.currentSpeed * 3.6 : 0.0;
        var altitude = (info != null && info.altitude != null) ? info.altitude : 0.0;
        var elapsedSec = (info != null && info.elapsedTime != null) ? info.elapsedTime / 1000 : 0;
        _totalDistance = (info != null && info.elapsedDistance != null) ? info.elapsedDistance / 1000.0 : 0.0;
        _totalDescend = (info != null && info.totalDescent != null) ? info.totalDescent.toFloat() : 0.0;

        if (_lastAltitude != null) {
            var diff = altitude - _lastAltitude;
            if (!_isDescending) {
                if (diff < -2.5 && speed > 9.0) { 
                    _isDescending = true;
                    _runCount++; 
                    _maxSpeedCurrentRun = 0.0; 
                    vibrate(1);
                }
            } else {
                if (diff > 3.5) { 
                    _isDescending = false;
                    _liftCount++; 
                    vibrate(2);
                }
            }
        }
        _lastAltitude = altitude.toFloat();

        if (_isDescending && speed > _maxSpeedCurrentRun) { _maxSpeedCurrentRun = speed.toFloat(); }
        if (speed > _topSpeedEver) { 
            _topSpeedEver = speed.toFloat(); 
            Storage.setValue("topSpeedEver", _topSpeedEver);
        }

        if (_session != null) {
            if (!_isPaused && speed < 1.0 && _session.isRecording()) { 
                _session.stop();
                _isPaused = true; _pauseTimer = 2; vibrate(1);
            } else if (_isPaused && speed > 5.0 && !_session.isRecording()) { 
                _session.start();
                _isPaused = false; _pauseTimer = 2; vibrate(1);
            }
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(cx, (h * 0.16).toNumber(), cx, (h * 0.88).toNumber());
        dc.drawLine((w * 0.05).toNumber(), cy, (w * 0.95).toNumber(), cy);

        var ringColor = (_gpsAccuracy >= 3) ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;
        if (_isPaused) { ringColor = Graphics.COLOR_RED; }
        
        dc.setPenWidth(10);
        dc.setColor(ringColor, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, cx - 6);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        dc.drawText(cx, (h * 0.06).toNumber(), Graphics.FONT_MEDIUM, Lang.format("$1$:$2$", [now.hour.format("%02d"), now.min.format("%02d")]), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.92).toNumber(), Graphics.FONT_TINY, System.getSystemStats().battery.format("%d") + "%", Graphics.TEXT_JUSTIFY_CENTER);

        // --- POZÍCIONÁLÁS ÉS IGAZÍTÁS ---
        var sideX = (w * 0.22).toNumber();
        var leftValueX = cx - 20; // A bal oldali értékek jobb széle ide lesz igazítva
        
        var topLabelY = (h * 0.18).toNumber();
        var topValueY = (h * 0.38).toNumber();
        var botLabelY = (h * 0.53).toNumber(); // Feljebb hozva (0.55-ről)
        var botValueY = (h * 0.73).toNumber(); // Feljebb hozva (0.80-ról)
        
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx - sideX, topLabelY, Graphics.FONT_XTINY, "ELAPS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx + sideX, topLabelY, Graphics.FONT_XTINY, "DIST", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx - sideX, botLabelY, Graphics.FONT_XTINY, "CUR MAX", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx + sideX, botLabelY, Graphics.FONT_XTINY, "RUNS", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        
        // ELAPS - Jobbra igazítva a középvonaltól
        dc.drawText(leftValueX, topValueY, Graphics.FONT_NUMBER_MILD, formatTime(elapsedSec.toNumber()), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        
        // DIST - Marad középen a jobb kvadránsban
        dc.drawText(cx + sideX + 10, topValueY, Graphics.FONT_NUMBER_MILD, _totalDistance.format("%.2f"), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        
        // CUR MAX - Jobbra igazítva ugyanoda, ahol az ELAPS véget ér
        dc.drawText(leftValueX, botValueY, Graphics.FONT_NUMBER_MILD, _maxSpeedCurrentRun.format("%.1f"), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        
        // RUNS - Marad középen a jobb kvadránsban
        dc.drawText(cx + sideX, botValueY, Graphics.FONT_NUMBER_MILD, _runCount.toString(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (_pauseTimer > 0) { 
            drawOverlayIcon(dc); 
            _pauseTimer--; 
        }
    }

    private function formatTime(seconds as Number) as String {
        var m = seconds / 60;
        var s = seconds % 60;
        return m.format("%d") + ":" + s.format("%02d");
    }

    private function drawOverlayIcon(dc as Dc) as Void {
        var x = dc.getWidth() / 2;
        var y = dc.getHeight() / 2;
        if (_isPaused) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
            dc.fillRectangle(x - 15, y - 20, 10, 40); 
            dc.fillRectangle(x + 5, y - 20, 10, 40);
        } else {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);
            dc.fillPolygon([[x - 15, y - 20], [x - 15, y + 20], [x + 20, y]]);
        }
    }
}