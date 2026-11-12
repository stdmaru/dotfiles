pragma Singleton

import qs.controllers
import Quickshell
import Quickshell.Io
import QtQuick

// Clima via OpenWeatherMap, com cache em disco para respeitar a cota da API.
// Configuração por variáveis de ambiente: _SHELL_WEATHER_API_KEY,
// _SHELL_WEATHER_LOCATION e _SHELL_WEATHER_LANG.
Singleton {
    id: root

    property bool hasData: false
    property string glyph: "\ue226"
    property double tempCurrent: 0
    property double tempMin: 0
    property double tempMax: 0
    property double tempFeelsLike: 0
    property string description: ""
    property string region: ""
    property string state: ""
    property string country: ""
    property var forecast: []

    readonly property int forecastIntervalMin: 6 * 60     // Previsão: a cada 6h
    readonly property int conditionIntervalMin: 60        // Condição atual: a cada 1h
    readonly property string cacheDir: Quickshell.shellDir + "/userdata/.cache/weather"
    readonly property string apiKey: Quickshell.env("_SHELL_WEATHER_API_KEY") ?? ""
    readonly property string location: Quickshell.env("_SHELL_WEATHER_LOCATION") ?? ""
    readonly property string language: (Quickshell.env("_SHELL_WEATHER_LANG") || "pt_br").toLowerCase()
    readonly property bool configured: apiKey !== "" && location !== ""
    readonly property string apiBase: "https://api.openweathermap.org"

    property bool started: false
    property bool refreshing: false
    property var _location: null
    property var _current: null
    property var _forecast: null

    FileView { id: locationFile; path: root.cacheDir + "/location.json"; blockLoading: true; printErrors: false }
    FileView { id: currentFile; path: root.cacheDir + "/current.json"; blockLoading: true; printErrors: false }
    FileView { id: forecastFile; path: root.cacheDir + "/forecast.json"; blockLoading: true; printErrors: false }

    Process {
        id: prepareCache
        command: ["mkdir", "-p", "--", root.cacheDir]
        onExited: root.refreshWeather()
    }

    Timer {
        interval: 10 * 60 * 1000
        running: root.started && root.configured
        repeat: true
        onTriggered: root.refreshWeather()
    }

    function init(): void {
        if (root.started)
            return
        root.started = true

        if (!root.configured) {
            console.warn("Weather disabled: set _SHELL_WEATHER_API_KEY and _SHELL_WEATHER_LOCATION")
            return
        }
        prepareCache.running = true
    }

    function refreshWeather(): void {
        if (!root.configured || root.refreshing)
            return
        root.refreshing = true
        loadLocation()
    }

    function readCache(file): var {
        try {
            const data = JSON.parse(file.text())
            return data && typeof data === "object" ? data : {}
        } catch (e) {
            return {}
        }
    }

    function isFresh(cache, maxAgeMin): bool {
        return cache.cod == 200
            && !!cache.lastUpdate
            && Date.now() <= cache.lastUpdate + maxAgeMin * 60 * 1000
            && cache.lastLocation?.name === root._location?.name
    }

    function openInBrowser(): void {
        const query = ["weather", root.region, root.state, root.country]
            .filter(part => part).join(" ")
        Quickshell.execDetached(["xdg-open",
            `https://www.google.com/search?q=${encodeURIComponent(query)}`])
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

        // ---- Agrupa as entradas de 3h em dias (no fuso da cidade)
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
        root.forecast = weather.forecast ?? []

        root.hasData = true
    }

    function loadLocation(): void {
        const cached = readCache(locationFile)
        if (cached.name && cached.lastSearchQuery === root.location) {
            root._location = cached
            loadCurrent()
            return
        }

        Utils.fetch({
            url: `${root.apiBase}/geo/1.0/direct`
                + `?q=${encodeURIComponent(root.location)}&limit=1&appid=${root.apiKey}`,
            success: response => {
                const found = Array.isArray(response) ? response[0] : null
                if (!found) {
                    console.warn(`Weather location not found: ${root.location}`)
                    root.refreshing = false
                    return
                }
                found.lastSearchQuery = root.location
                locationFile.setText(JSON.stringify(found))
                root._location = found
                loadCurrent()
            },
            error: (response, status) => {
                console.warn(`Failed to load weather location (HTTP ${status})`)
                // Sem rede: reaproveita a última localização conhecida.
                if (cached.name) {
                    root._location = cached
                    loadCurrent()
                } else {
                    root.refreshing = false
                }
            }
        })
    }

    function coordinatesQuery(): string {
        return `?lat=${root._location.lat}&lon=${root._location.lon}`
            + `&appid=${root.apiKey}&lang=${root.language}&units=metric`
    }

    function loadCurrent(): void {
        const cached = readCache(currentFile)
        if (isFresh(cached, root.conditionIntervalMin)) {
            root._current = cached
            loadForecast()
            return
        }

        Utils.fetch({
            url: `${root.apiBase}/data/2.5/weather${coordinatesQuery()}`,
            success: response => {
                response.lastUpdate = Date.now()
                response.lastLocation = root._location
                currentFile.setText(JSON.stringify(response))
                root._current = response
                loadForecast()
            },
            error: (response, status) => {
                console.warn(`Failed to load current weather (HTTP ${status})`)
                // Dados antigos são melhores do que nenhum dado.
                root._current = cached.weather ? cached : root._current
                loadForecast()
            }
        })
    }

    function loadForecast(): void {
        const cached = readCache(forecastFile)
        if (isFresh(cached, root.forecastIntervalMin)) {
            root._forecast = cached
            finalizeWeather()
            return
        }

        Utils.fetch({
            url: `${root.apiBase}/data/2.5/forecast${coordinatesQuery()}`,
            success: response => {
                response.lastUpdate = Date.now()
                response.lastLocation = root._location
                forecastFile.setText(JSON.stringify(response))
                root._forecast = response
                finalizeWeather()
            },
            error: (response, status) => {
                console.warn(`Failed to load weather forecast (HTTP ${status})`)
                root._forecast = cached.list ? cached : root._forecast
                finalizeWeather()
            }
        })
    }

    function finalizeWeather(): void {
        root.refreshing = false
        if (!root._current)
            return
        applyWeather(buildWeather(root._location, root._current, root._forecast))
    }

    function getGlyph(icon): string {
        switch(icon)
        {
            case "01d": return "\uf185"; // Sun
            case "01n": return "\uf186"; // Moon

            case "02d": return "\ueef0"; // Few clouds
            case "02n": return "\ueeef"; // -- Small cloud with sun/moon

            case "03d": return "\ue21d"; // Scattered clouds
            case "03n": return "\ue226"; // -- Great cloud with sun/moon

            case "04d": return "\uf0c2"; // Broken clouds
            case "04n": return "\uf0c2"; // -- Full clouds

            case "09d": return "\uef1e"; // Shower rain
            case "09n": return "\uef1b"; // -- Rain with sun/moon
            case "10d": return "\uef1e"; // Rain
            case "10n": return "\uef1b"; // -- Rain with sun/moon
            
            case "11d": return "\ue208"; // Thunderstorm
            case "11n": return "\ue208";
            case "13d": return "\uf2dc"; // Snow
            case "13n": return "\uf2dc";
            case "50d": return "\ue303"; // Mist / haze
            case "50n": return "\ue346";
    
            default: return "\ue226";
        }
    }
}
