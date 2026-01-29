import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Attention;
import Toybox.Application.Storage;
import Toybox.System;
import Toybox.Lang;

class SnowBoardAppView extends WatchUi.View {
    // Erőforrások és állapotok
    private var _backgroundImage as BitmapResource?;
    private var _session as Session?;
    private var _isTracking as Boolean = false;
    private var _isPaused as Boolean = false;
    private var _gpsAccuracy as Number = 0;
    private var _pauseTimer as Number = 0;
    
    // Snowboard adatok
    private var _runCount as Number = 0;
    private var _liftCount as Number = 0;
    private var _maxSpeedCurrentRun as Float = 0.0;
    private var _topSpeedEver as Float = 0.0;
    private var _totalDescend as Float = 0.0;
    private var _lastAltitude as Float? = null;
    private var _isDescending as Boolean = false;

    function initialize() {
        View.initialize();
        
        // Háttérkép betöltése manuálisan a drawables-ből
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
        // Üresen hagyjuk, mert mindent onUpdate-ben rajzolunk
    }

    function isTracking() as Boolean {
        return _isTracking;
    }

    // --- RÖGZÍTÉS KEZELÉSE ---

    function startTracking() as Void {
        if (Toybox has :ActivityRecording && _session == null) {
            _session = ActivityRecording.createSession({
                :name => "Snowboard",
                :sport => Activity.SPORT_SNOWBOARDING
            });
            _session.start();
            _isTracking = true;
            _runCount = 1;
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
            _pauseTimer = 5; // 5 másodpercig mutatjuk az ikont
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

    // --- VIBRÁCIÓ ---

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

    // --- RAJZOLÁS ---

    function onUpdate(dc as Dc) as Void {
        // Képernyő törlése (Fekete háttér alapértelmezetten)
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
        // 1. Háttérkép
        if (_backgroundImage != null) {
            dc.drawBitmap(0, 0, _backgroundImage);
        }

        // 2. GPS Állapot Kör
        _gpsAccuracy = (info != null && info.currentLocationAccuracy != null) ? info.currentLocationAccuracy : 0;
        var ringColor = (_gpsAccuracy >= 3) ? Graphics.COLOR_GREEN : Graphics.COLOR_RED;
        
        dc.setPenWidth(8);
        dc.setColor(ringColor, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(dc.getWidth()/2, dc.getHeight()/2, (dc.getWidth()/2) - 4);
        
        // 3. Szöveges állapot
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var statusText = (_gpsAccuracy >= 3) ? "START-ra kész!" : "GPS keresése...";
        dc.drawText(dc.getWidth()/2, dc.getHeight() - 60, Graphics.FONT_XTINY, statusText, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawMainScreen(dc as Dc, info as Activity.Info?) as Void {
        var speed = (info != null && info.currentSpeed != null) ? info.currentSpeed * 3.6 : 0.0;
        var altitude = (info != null && info.altitude != null) ? info.altitude : 0.0;
        var elapsedTime = (info != null && info.elapsedTime != null) ? info.elapsedTime / 1000 : 0;
        _totalDescend = (info != null && info.totalDescent != null) ? info.totalDescent.toFloat() : 0.0;

        // Run és Lift logika (Magasság alapú)
        if (_lastAltitude != null) {
            var diff = altitude - _lastAltitude;
            if (diff < -1.5 && !_isDescending) { 
                _isDescending = true;
                _maxSpeedCurrentRun = 0.0;
            } else if (diff > 2.0 && _isDescending) {
                _isDescending = false;
                _runCount++;
                _liftCount++;
                vibrate(1);
            }
        }
        _lastAltitude = altitude.toFloat();

        // Rekord és Max sebesség figyelés
        if (_isDescending) {
            if (speed > _maxSpeedCurrentRun) { _maxSpeedCurrentRun = speed.toFloat(); }
            if (speed > _topSpeedEver) {
                _topSpeedEver = speed.toFloat();
                Storage.setValue("topSpeedEver", _topSpeedEver);
                vibrate(3);
            }
        }

        // Auto-Pause rögzítés közben
        if (_session != null) {
            if (!_isPaused && speed < 2.0 && _session.isRecording()) { 
                _session.stop(); _isPaused = true; _pauseTimer = 5; vibrate(1); 
            } else if (_isPaused && speed > 5.0 && !_session.isRecording()) { 
                _session.start(); _isPaused = false; _pauseTimer = 5; vibrate(1); 
            }
        }

        var w = dc.getWidth();
        var h = dc.getHeight();

        // Grafikai elrendezés (Vonalak)
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, h*0.3, w, h*0.3);
        dc.drawLine(0, h*0.7, w, h*0.7);

        // FELSŐ SÁV (Idő és Körök)
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, 15, Graphics.FONT_XTINY, formatTime(elapsedTime), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, 40, Graphics.FONT_SMALL, "RUNS: " + _runCount, Graphics.TEXT_JUSTIFY_CENTER);

        // KÖZÉPSŐ SÁV (Sebesség)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h/2 - 35, Graphics.FONT_NUMBER_THAI_HOT, speed.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w/2, h/2 + 25, Graphics.FONT_TINY, "TOP: " + _topSpeedEver.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);

        // ALSÓ SÁV (Süllyedés és Max Run Speed)
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w*0.25, h*0.75, Graphics.FONT_XTINY, "DESC", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w*0.75, h*0.75, Graphics.FONT_XTINY, "MAX R", Graphics.TEXT_JUSTIFY_CENTER);
        
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w*0.25, h*0.85, Graphics.FONT_SMALL, _totalDescend.format("%d") + "m", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w*0.75, h*0.85, Graphics.FONT_SMALL, _maxSpeedCurrentRun.format("%.1f"), Graphics.TEXT_JUSTIFY_CENTER);

        // Overlay ikon (Play/Pause)
        if (_pauseTimer > 0) {
            drawOverlayIcon(dc);
            _pauseTimer--;
        }
    }

    private function formatTime(seconds as Number) as String {
        var hh = seconds / 3600;
        var mm = (seconds % 3600) / 60;
        var ss = seconds % 60;
        return hh.format("%02d") + ":" + mm.format("%02d") + ":" + ss.format("%02d");
    }

    // Session elvetése mentés nélkül
    function stopAndDiscard() as Void {
        if (_session != null) {
            _session.stop();
            _session.discard(); // Törli a FIT fájlt, nem menti el
            _session = null;
            _isTracking = false;
        }
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
            var pts = [[cx - 15, cy - 20], [cx - 15, cy + 20], [cx + 20, cy]] as Array<Array<Number>>;
            dc.fillPolygon(pts);
        }
    }
}