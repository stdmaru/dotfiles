pragma Singleton

import qs.controllers
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property int loadStep: 0
    property var _location
    property var _current
    property var _forecast

    property bool hasData: false
    property string glyph: ""
    property double tempCurrent: 0
    property double tempMin: 0
    property double tempMax: 0
    property double tempFeelsLike: 0
    property string description: ""
    property string region: ""
    property string state: ""
    property string country: ""

    readonly property int forecastIntervalMin: 6 * 60     // Forecast reload interval in 6h
    readonly property int conditionIntervalMin: 60        // Condition reload interval in 1h
    readonly property string cacheDir: Quickshell.shellDir + "/userdata/.cache/weather"
    readonly property string apiKey: Quickshell.env("_SHELL_WEATHER_API_KEY")
    readonly property string location: Quickshell.env("_SHELL_WEATHER_LOCATION")
    readonly property string language: Quickshell.env("_SHELL_WEATHER_LANG")
    readonly property FileView locationFile: FileView { path: Qt.resolvedUrl(root.cacheDir + "/location.json"); blockLoading: true; printErrors: false; }
    readonly property FileView currentFile: FileView { path: Qt.resolvedUrl(root.cacheDir + "/current.json"); blockLoading: true; printErrors: false; }
    readonly property FileView forecastFile: FileView { path: Qt.resolvedUrl(root.cacheDir + "/forecast.json"); blockLoading: true; printErrors: false; }
    readonly property var timer: Timer { interval: 10 * 60 * 1000; running: true; repeat: true; onTriggered: root.refreshWeather() }

    function init(): void {
        console.info("Weather daemon started")
        root.refreshWeather()
    }

    function refreshWeather() {
        loadStep = 0
        loadLocation()
    }

    function ensureFilesExists() {
        Quickshell.execDetached(["mkdir", "-p", cacheDir])
        Quickshell.execDetached(["touch", cacheDir + "/location.json"])
        Quickshell.execDetached(["touch", cacheDir + "/current.json"])
        Quickshell.execDetached(["touch", cacheDir + "/forecast.json"])
    }

    function buildWeather(location, current, forecast): var {
        const weather = {}

        weather.location = location
        weather.current = current
        weather.forecast = []

        if (!current || !current.weather || !current.weather[0])
            return weather

        // Glyph
        weather.current.glyph = root.getGlyph(current.weather[0].icon)

        // Timezone
        let tzOffset = -3 * 3600
        if (forecast?.city?.timezone !== undefined)
            tzOffset = forecast.city.timezone
        else if (location?.timezone !== undefined)
            tzOffset = location.timezone

        // ---- Build daily forecast (mesma lógica que você já tinha)
        const dailyMap = new Map()

        if (forecast && Array.isArray(forecast.list)) {
            for (const entry of forecast.list) {
                const localDate = new Date((entry.dt + tzOffset) * 1000)
                const y = localDate.getUTCFullYear()
                const m = String(localDate.getUTCMonth() + 1).padStart(2, '0')
                const d = String(localDate.getUTCDate()).padStart(2, '0')
                const dateKey = `${y}-${m}-${d}`
                const hour = localDate.getUTCHours()

                if (!dailyMap.has(dateKey)) {
                    dailyMap.set(dateKey, {
                        min: entry.main?.temp_min ?? entry.main?.temp ?? null,
                        max: entry.main?.temp_max ?? entry.main?.temp ?? null,
                        icon: entry.weather?.[0]?.icon ?? null,
                        description: entry.weather?.[0]?.description ?? null,
                        dayNameShort: localDate.toLocaleDateString(
                            'pt-br',
                            { weekday: 'short', timeZone: 'UTC' }
                        )
                    })
                } else {
                    const cur = dailyMap.get(dateKey)
                    cur.min = Math.min(cur.min, entry.main?.temp_min ?? cur.min)
                    cur.max = Math.max(cur.max, entry.main?.temp_max ?? cur.max)

                    if (hour === 12 && entry.weather?.[0]?.icon) {
                        cur.icon = entry.weather[0].icon
                        cur.description = entry.weather[0].description
                    }
                }
            }
        }

        // ---- Build ordered array (today + 4)
        const startLocal = new Date(Date.now() + tzOffset * 1000)
        const baseY = startLocal.getUTCFullYear()
        const baseM = startLocal.getUTCMonth()
        const baseD = startLocal.getUTCDate()

        for (let i = 0; i < 5; i++) {
            const dt = new Date(Date.UTC(baseY, baseM, baseD + i))
            const key =
                `${dt.getUTCFullYear()}-` +
                `${String(dt.getUTCMonth() + 1).padStart(2, '0')}-` +
                `${String(dt.getUTCDate()).padStart(2, '0')}`

            const day = dailyMap.get(key)
            if (day) {
                weather.forecast.push({
                    date: key,
                    dayNameShort: day.dayNameShort,
                    min: Math.round(day.min),
                    max: Math.round(day.max),
                    icon: day.icon,
                    description: day.description,
                    glyph: root.getGlyph(day.icon)
                })
            }
        }

        return weather
    }

    function applyWeather(weather: var): void {
        if (!weather?.current || !weather?.location)
            return

        root.glyph = weather.current.glyph ?? "?"
        root.tempCurrent = Math.round(weather.current.main?.temp ?? 0)
        root.tempFeelsLike = Math.round(weather.current.main?.feels_like ?? 0)

        if (weather.forecast && weather.forecast[0]) {
            root.tempMin = Math.round(weather.forecast[0].min ?? 0)
            root.tempMax = Math.round(weather.forecast[0].max ?? 0)
        }

        root.description = weather.current.weather?.[0]?.description ?? ""
        root.region = weather.location.name ?? ""
        root.state = weather.location.state ?? ""
        root.country = weather.location.country ?? ""

        root.hasData = true
    }

    function loadLocation() {
        ensureFilesExists()

        var loc = {}
        try { loc = JSON.parse(root.locationFile.text()) } catch(e) {}

        if (loc.name && loc.lastSearchQuery === root.location) {
            _location = loc
            loadCurrent()
            return
        }

        const callUrl =
            `http://api.openweathermap.org/geo/1.0/direct` +
            `?q=${root.location}&limit=1&appid=${root.apiKey}`

        Utils.fetch({
            method: "GET",
            url: callUrl,
            success: (response) => {
                loc = response[0]
                loc.lastSearchQuery = root.location
                root.locationFile.setText(JSON.stringify(loc))
                _location = loc
                loadCurrent()
            },
            error: () => console.warn("Failed to load location")
        })
    }

    function loadCurrent() {
        var cur = {}
        try { cur = JSON.parse(root.currentFile.text()) } catch(e) {}

        const expired =
            !cur.lastUpdate ||
            Date.now() > cur.lastUpdate + root.conditionIntervalMin * 60 * 1000

        if (cur.cod === "200" && !expired && cur.lastLocation?.name === _location.name) {
            _current = cur
            loadForecast()
            return
        }

        const callUrl =
            `https://api.openweathermap.org/data/2.5/weather` +
            `?lat=${_location.lat}&lon=${_location.lon}` +
            `&appid=${root.apiKey}&lang=${root.language}&units=metric`

        Utils.fetch({
            method: "GET",
            url: callUrl,
            success: (response) => {
                response.lastUpdate = Date.now()
                response.lastLocation = _location
                root.currentFile.setText(JSON.stringify(response))
                _current = response
                loadForecast()
            },
            error: () => console.warn("Failed to load current weather")
        })
    }

    function loadForecast() {
        var frc = {}
        try { frc = JSON.parse(root.forecastFile.text()) } catch(e) {}

        const expired =
            !frc.lastUpdate ||
            Date.now() > frc.lastUpdate + root.forecastIntervalMin * 60 * 1000

        if (frc.cod === "200" && !expired && frc.lastLocation?.name === _location.name) {
            _forecast = frc
            finalizeWeather()
            return
        }

        const callUrl =
            `http://api.openweathermap.org/data/2.5/forecast` +
            `?lat=${_location.lat}&lon=${_location.lon}` +
            `&appid=${root.apiKey}&lang=${root.language}&units=metric`

        Utils.fetch({
            method: "GET",
            url: callUrl,
            success: (response) => {
                response.lastUpdate = Date.now()
                response.lastLocation = _location
                root.forecastFile.setText(JSON.stringify(response))
                _forecast = response
                finalizeWeather()
            },
            error: () => console.warn("Failed to load forecast")
        })
    }

    function finalizeWeather() {
        const weather = buildWeather(_location, _current, _forecast)
        applyWeather(weather)
        console.info("Weather updated")
    }

    function getGlyph(icon): string {
        switch(icon)
        {
            case "01d": return ""; // clear sky
            case "01n": return ""; 
            case "02d": return ""; // few clouds
            case "02n": return "";
            case "03d": return ""; // scattered clouds
            case "03n": return "";
            case "04d": return ""; // broken clouds
            case "04n": return "";
            case "09d": return ""; // shower rain
            case "09n": return "";
            case "10d": return ""; // rain
            case "10n": return "";
            case "11d": return ""; // thunderstorm
            case "11n": return "";
            case "13d": return ""; // snow
            case "13n": return "";
            case "50d": return ""; // mist 
            case "50n": return "";
    
            default: return "?";
        }
    }
}