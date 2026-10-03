use std::collections::HashMap;

pub struct TrayI18n {
    strings: HashMap<&'static str, &'static str>,
}

impl TrayI18n {
    pub fn new(lang: &str) -> Self {
        let mut strings = HashMap::new();
        match lang {
            "pl" => {
                strings.insert("quit", "Zamknij");
                strings.insert("settings", "Ustawienia");
                strings.insert("clean_now", "Posprzątaj teraz");
                strings.insert("tooltip", "MouziFlow");
                strings.insert("tooltip_one_pending", "MouziFlow – {} plik czeka");
                strings.insert("tooltip_many_pending", "MouziFlow – {} pliki czekają");
                strings.insert("popup_title", "MouziFlow");
                strings.insert("settings_title", "Ustawienia MouziFlow");
                strings.insert("organized", "Uporządkowano {} plik(i)");
            }
            "it" => {
                strings.insert("quit", "Esci");
                strings.insert("settings", "Impostazioni");
                strings.insert("clean_now", "Pulisci ora");
                strings.insert("tooltip", "MouziFlow");
                strings.insert("tooltip_one_pending", "MouziFlow – {} file in attesa");
                strings.insert("tooltip_many_pending", "MouziFlow – {} file in attesa");
                strings.insert("popup_title", "MouziFlow");
                strings.insert("settings_title", "Impostazioni MouziFlow");
                strings.insert("organized", "Organizzati {} file");
            }
            "de" => {
                strings.insert("quit", "Beenden");
                strings.insert("settings", "Einstellungen");
                strings.insert("clean_now", "Jetzt aufräumen");
                strings.insert("tooltip", "MouziFlow");
                strings.insert("tooltip_one_pending", "MouziFlow – {} Datei wartend");
                strings.insert("tooltip_many_pending", "MouziFlow – {} Dateien wartend");
                strings.insert("popup_title", "MouziFlow");
                strings.insert("settings_title", "MouziFlow Einstellungen");
                strings.insert("organized", "{} Datei(en) organisiert");
            }
            "fr" => {
                strings.insert("quit", "Quitter");
                strings.insert("settings", "Paramètres");
                strings.insert("clean_now", "Nettoyer maintenant");
                strings.insert("tooltip", "MouziFlow");
                strings.insert("tooltip_one_pending", "MouziFlow – {} fichier en attente");
                strings.insert("tooltip_many_pending", "MouziFlow – {} fichiers en attente");
                strings.insert("popup_title", "MouziFlow");
                strings.insert("settings_title", "Paramètres MouziFlow");
                strings.insert("organized", "{} fichier(s) organisé(s)");
            }
            "ru" => {
                strings.insert("quit", "Выход");
                strings.insert("settings", "Настройки");
                strings.insert("clean_now", "Очистить сейчас");
                strings.insert("tooltip", "MouziFlow");
                strings.insert("tooltip_one_pending", "MouziFlow – {} файл ожидает");
                strings.insert("tooltip_many_pending", "MouziFlow – {} файла ожидают");
                strings.insert("popup_title", "MouziFlow");
                strings.insert("settings_title", "Настройки MouziFlow");
                strings.insert("organized", "Организовано {} файл(ов)");
            }
            "ja" => {
                strings.insert("quit", "終了");
                strings.insert("settings", "設定");
                strings.insert("clean_now", "今すぐ整理");
                strings.insert("tooltip", "MouziFlow");
                strings.insert("tooltip_one_pending", "MouziFlow – {} 個のファイルが待機中");
                strings.insert("tooltip_many_pending", "MouziFlow – {} 個のファイルが待機中");
                strings.insert("popup_title", "MouziFlow");
                strings.insert("settings_title", "MouziFlowの設定");
                strings.insert("organized", "{}個のファイルを整理しました");
            }
            "vi" => {
                strings.insert("quit", "Thoát");
                strings.insert("settings", "Cài đặt");
                strings.insert("clean_now", "Dọn dẹp ngay");
                strings.insert("tooltip", "MouziFlow");
                strings.insert("tooltip_one_pending", "MouziFlow – {} tệp đang chờ");
                strings.insert("tooltip_many_pending", "MouziFlow – {} tệp đang chờ");
                strings.insert("popup_title", "MouziFlow");
                strings.insert("settings_title", "Cài đặt MouziFlow");
                strings.insert("organized", "Đã sắp xếp {} tệp");
            }
            "es" => {
                strings.insert("quit", "Salir");
                strings.insert("settings", "Configuración");
                strings.insert("clean_now", "Limpiar ahora");
                strings.insert("tooltip", "MouziFlow");
                strings.insert("tooltip_one_pending", "MouziFlow – {} archivo esperando");
                strings.insert("tooltip_many_pending", "MouziFlow – {} archivos esperando");
                strings.insert("popup_title", "MouziFlow");
                strings.insert("settings_title", "Configuración de MouziFlow");
                strings.insert("organized", "{} archivo(s) organizado(s)");
            }
            "uk" => {
                strings.insert("quit", "Вийти");
                strings.insert("settings", "Налаштування");
                strings.insert("clean_now", "Прибрати зараз");
                strings.insert("tooltip", "MouziFlow");
                strings.insert("tooltip_one_pending", "MouziFlow — очікує {} файл");
                strings.insert("tooltip_many_pending", "MouziFlow — очікує файлів: {}");
                strings.insert("popup_title", "MouziFlow");
                strings.insert("settings_title", "Налаштування MouziFlow");
                strings.insert("organized", "Впорядковано файлів: {}");
            }
            _ => {
                strings.insert("quit", "Quit");
                strings.insert("settings", "Settings");
                strings.insert("clean_now", "Clean Now");
                strings.insert("tooltip", "MouziFlow");
                strings.insert("tooltip_one_pending", "MouziFlow – {} file waiting");
                strings.insert("tooltip_many_pending", "MouziFlow – {} files waiting");
                strings.insert("popup_title", "MouziFlow");
                strings.insert("settings_title", "MouziFlow Settings");
                strings.insert("organized", "Organized {} file(s)");
            }
        }
        Self { strings }
    }

    pub fn get<'a>(&self, key: &'a str) -> &'a str {
        self.strings.get(key).copied().unwrap_or(key)
    }
}
