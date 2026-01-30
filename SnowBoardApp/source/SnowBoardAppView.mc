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
    // --- OSZTÁLY VÁLTOZÓK ---
    private var _backgroundImage as BitmapResource?;
    private var _session as Session? = null;
    private var _isTracking as Boolean = false;
    private var _isPaused as Boolean = false;
    private var _gpsAccuracy as Number = 0;
    private var _pauseTimer as Number = 0;

    // Snowboard specifikus adatok
    private var _runCount as Number = 0;
    private var _liftCount as Number = 0;
    private var _maxSpeedCurrentRun as Float = 0.0;
    private var _topSpeedEver as Float = 0.0;
    private var _totalDescend as Float = 0.0;
    private var _totalDistance as Float = 0.0;
    private var _lastAltitude as Float? = null;
    private var _isDescending as Boolean = false;

    // --- INICIALIZÁLÁS ---
    function initialize() {
        View.initialize();
        
        // Háttérkép betöltése az erőforrásokból
        if (Rez.Drawables has :BackgroundImage) {
            _backgroundImage = WatchUi.loadResource(Rez.Drawables.BackgroundImage) as BitmapResource;
        }
        
        // Rekord sebesség betöltése a memóriából
        var savedTopSpeed = Storage.getValue("topSpeedEver");
        if (savedTopSpeed != null) {
            _topSpeedEver = savedTopSpeed.toFloat();
        }
    }

    function onLayout(dc as Dc) as Void {
        // A layout-ot manuálisan kezeljük az onUpdate-ben
    }

    // --- ADATLEKÉRŐK ---
    function isTracking() as Boolean {
        return _isTracking;
    }

    function hasActiveSession() as Boolean {
        return _session != null;
    }

    function getRunCount() as Number {
        return _runCount;
    }

    function getLiftCount() as Number {
        return _liftCount;
    }

    function getMaxSpeed() as Float {
        return _topSpeedEver;
    }

    function getTotalDescend() as Float {
        return _totalDescend;
    }

    function getTotalDistance() as Float {
        return _totalDistance;
    }

    // --- RÖGZÍTÉS VEZÉRLÉSE ---
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

    // --- JELZÉSEK ---
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

    // --- FŐ RAJZOLÁSI CIKLUS ---
    function onUpdate(dc as Dc) as Void {
        // Képernyő törlése (AMOLED fekete)
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var info = Activity.getActivityInfo();

        if (!_isTracking) {
            drawStartScreen(dc, info);
        } else {
            drawMainScreen(dc, info);
        }
    }

    // --- KEZDŐ KÉPERNYŐ (v1.0 felirattal) ---
    private function drawStartScreen(dc as Dc, info as Activity.Info?) as Void {
        if (_backgroundImage != null) {
            dc.drawBitmap(0, 0, _backgroundImage);
        }

        // Verziószám v1.0
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth()/2, (dc.getHeight() * 0.88).toNumber(), Graphics.FONT_XTINY, "v1.0", Graphics.TEXT_JUSTIFY_CENTER);

        _gpsAccuracy = (info != null && info.currentLocationAccuracy != null) ? info.currentLocationAccuracy : 0;
        var ringColor = (_gpsAccuracy >= 3) ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;
        
        dc.setPenWidth(8);
        dc.setColor(ringColor, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(dc.getWidth()/2, dc.getHeight()/2, (dc.getWidth()/2) - 4);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var statusText = (_gpsAccuracy >= 3) ? "START-ra kész!" : "GPS keresése...";
        dc.drawText(dc.getWidth()/2, (dc.getHeight() * 0.72).toNumber(), Graphics.FONT_XTINY, statusText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // --- ADAT KÉPERNYŐ ---
    private function drawMainScreen(dc as Dc, info as Activity.Info?) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var centerX = w / 2;
        var centerY = h / 2;

        // Adatok lekérése
        var speed = (info != null && info.currentSpeed != null) ? info.currentSpeed * 3.6 : 0.0;
        var altitude = (info != null && info.altitude != null) ? info.altitude : 0.0;
        var elapsedSec = (info != null && info.elapsedTime != null) ? info.elapsedTime / 1000 : 0;
        _totalDistance = (info != null && info.elapsedDistance != null) ? info.elapsedDistance / 1000.0 : 0.0;

        // Run/Lift logika
        if (_lastAltitude != null) {
            var diff = altitude - _lastAltitude;
            if (!_isDescending && diff < -1.5 && speed > 7.0) { 
                _isDescending = true; 
                _runCount++; 
                _maxSpeedCurrentRun = 0.0; 
                vibrate(1);
            } else if (_isDescending && diff > 2.5) { 
                _isDescending = false; 
                _liftCount++; 
                vibrate(2);
            }
        }
        _lastAltitude = altitude.toFloat();

        // Sebesség rögzítés
        if (_isDescending && speed > _maxSpeedCurrentRun) {
            _maxSpeedCurrentRun = speed.toFloat();
        }
        if (speed > _topSpeedEver) {
            _topSpeedEver = speed.toFloat();
            Storage.setValue("topSpeedEver", _topSpeedEver);
        }

        // Auto-Pause logika
        if (_session != null) {
            if (!_isPaused && speed < 1.5 && _session.isRecording()) {
                _session.stop();
                _isPaused = true;
                _pauseTimer = 2;
                vibrate(1);
            } else if (_isPaused && speed > 4.0 && !_session.isRecording()) {
                _session.start();
                _isPaused = false;
                _pauseTimer = 2;
                vibrate(1);
            }
        }

        // --- VIZUÁLIS ELEMEK ---

        // Piros gyűrű pause esetén
        if (_isPaused) {
            dc.setPenWidth(10);
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(centerX, centerY, centerX - 5);
        }

        // Rövidített rács vonalak
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(centerX, (centerY - 35).toNumber(), centerX, (centerY + 35).toNumber());
        dc.drawLine((centerX - 70).toNumber(), centerY, (centerX + 70).toNumber(), centerY);

        // Pontos idő (Felül)
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var timeStr = Lang.format("$1$:$2$", [now.hour.format("%02d"), now.min.format("%02d")]);
        dc.drawText(centerX, (h * 0.12).toNumber(), Graphics.FONT_MEDIUM, timeStr, Graphics.TEXT_JUSTIFY_CENTER);

        // Akkumulátor (Alul - v1.0 nélkül)
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var batteryStr = System.getSystemStats().battery.format("%d") + "%";
        dc.drawText(centerX, (h * 0.88).toNumber(), Graphics.FONT_TINY, batteryStr, Graphics.TEXT_JUSTIFY_CENTER);

        // --- ADATMEZŐK ELRENDEZÉSE (Széttolva a fotók alapján) ---
        var sideOffset = 72; // Maximális távolság oldalra
        var topLabelY = (centerY - 80).toNumber();
        var topValueY = (centerY - 55).toNumber();
        var botLabelY = (centerY + 12).toNumber();
        var botValueY = (centerY + 37).toNumber();

        // 1. BAL FELÜL - Eltelt idő
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX - sideOffset, topLabelY, Graphics.FONT_XTINY, "ELAPS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX - sideOffset, topValueY, Graphics.FONT_NUMBER_MEDIUM, formatTime(elapsedSec.toNumber()), Graphics.TEXT_JUSTIFY_CENTER);

        // 2. JOBB FELÜL - Távolság
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX + sideOffset, topLabelY, Graphics.FONT_XTINY, "DIST", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX + sideOffset, topValueY, Graphics.FONT_NUMBER_MEDIUM, _totalDistance.format("%.2f"), Graphics.TEXT_JUSTIFY_CENTER);

        // 3. BAL ALUL - Aktuális Max Sebesség
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX - sideOffset, botLabelY, Graphics.FONT_XTINY, "CUR MAX", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX - sideOffset, botValueY, Graphics.FONT_NUMBER_MEDIUM, _maxSpeedCurrentRun.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);

        // 4. JOBB ALUL - Menetek száma
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX + sideOffset, botLabelY, Graphics.FONT_XTINY, "RUNS", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX + sideOffset, botValueY, Graphics.FONT_NUMBER_MEDIUM, _runCount.toString(), Graphics.TEXT_JUSTIFY_CENTER);

        // Overlay ikonok kezelése
        if (_pauseTimer > 0) {
            drawOverlayIcon(dc);
            _pauseTimer--;
        }
    }

    // --- SEGÉDFÜGGVÉNYEK ---
    private function formatTime(seconds as Number) as String {
        var min = seconds / 60;
        var sec = seconds % 60;
        return min.format("%d") + ":" + sec.format("%02d");
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
            var pts = [
                [cx - 15, cy - 20],
                [cx - 15, cy + 20],
                [cx + 20, cy]
            ] as Array;
            dc.fillPolygon(pts);
        }
    }
}