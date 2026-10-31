import Foundation

/// Translations keyed by the English UI string. Simplified Chinese and English
/// are passed directly at the call site; this table supplies the other four UI
/// languages.
enum Translations {
    static let table: [String: [AppLanguage: String]] = [
        "Screenshot": [
            .traditionalChinese: "截圖",
            .japanese: "スクリーンショット",
            .french: "Capture d'écran",
            .spanish: "Captura de pantalla"
        ],
        "Capture Window": [
            .traditionalChinese: "視窗截圖",
            .japanese: "ウインドウ撮影",
            .french: "Capturer une fenêtre",
            .spanish: "Capturar ventana"
        ],
        "Pin Last Screenshot": [
            .traditionalChinese: "釘選上一張截圖",
            .japanese: "直前のスクリーンショットをピン留め",
            .french: "Épingler la dernière capture",
            .spanish: "Fijar última captura"
        ],
        "Save Last Screenshot…": [
            .traditionalChinese: "儲存上一張截圖…",
            .japanese: "直前のスクリーンショットを保存…",
            .french: "Enregistrer la dernière capture…",
            .spanish: "Guardar última captura…"
        ],
        "Recognize Text": [
            .traditionalChinese: "辨識文字",
            .japanese: "文字を認識",
            .french: "Reconnaître le texte",
            .spanish: "Reconocer texto"
        ],
        "Scan QR Code": [
            .traditionalChinese: "掃描 QR Code",
            .japanese: "QR コードをスキャン",
            .french: "Scanner un QR code",
            .spanish: "Escanear código QR"
        ],
        "Settings…": [
            .traditionalChinese: "設定…",
            .japanese: "設定…",
            .french: "Réglages…",
            .spanish: "Ajustes…"
        ],
        "Launch at Login": [
            .traditionalChinese: "登入時啟動",
            .japanese: "ログイン時に起動",
            .french: "Lancer à l'ouverture de session",
            .spanish: "Iniciar al iniciar sesión"
        ],
        "About Shotjoy": [
            .traditionalChinese: "關於 Shotjoy",
            .japanese: "Shotjoy について",
            .french: "À propos de Shotjoy",
            .spanish: "Acerca de Shotjoy"
        ],
        "Quit Shotjoy": [
            .traditionalChinese: "結束 Shotjoy",
            .japanese: "Shotjoy を終了",
            .french: "Quitter Shotjoy",
            .spanish: "Salir de Shotjoy"
        ],
        "Fix Screen Recording Permission…": [
            .traditionalChinese: "修復螢幕錄製權限…",
            .japanese: "画面収録の権限を修復…",
            .french: "Réparer l'autorisation d'enregistrement de l'écran…",
            .spanish: "Reparar permiso de grabación de pantalla…"
        ],
        "Check Screen Recording Permission…": [
            .traditionalChinese: "檢查螢幕錄製權限…",
            .japanese: "画面収録の権限を確認…",
            .french: "Vérifier l'autorisation d'enregistrement de l'écran…",
            .spanish: "Comprobar permiso de grabación de pantalla…"
        ],
        "Screen Recording Permission Needed": [
            .traditionalChinese: "需要螢幕錄製權限",
            .japanese: "画面収録の権限が必要です",
            .french: "Autorisation d'enregistrement de l'écran requise",
            .spanish: "Se necesita permiso de grabación de pantalla"
        ],
        "Shotjoy needs Screen Recording permission to take screenshots. Turn Shotjoy on in System Settings → Privacy & Security → Screen Recording, then try again.": [
            .traditionalChinese: "Shotjoy（截趣）需要「螢幕錄製」權限才能截圖。請在「系統設定 → 隱私權與安全性 → 螢幕錄製」中開啟 Shotjoy，然後重新截圖。",
            .japanese: "Shotjoy（截趣）がスクリーンショットを撮るには「画面収録」の権限が必要です。「システム設定 → プライバシーとセキュリティ → 画面収録」で Shotjoy をオンにして、もう一度お試しください。",
            .french: "Shotjoy（截趣）a besoin de l'autorisation « Enregistrement de l'écran » pour capturer. Activez Shotjoy dans Réglages Système → Confidentialité et sécurité → Enregistrement de l'écran, puis réessayez.",
            .spanish: "Shotjoy（截趣）necesita el permiso «Grabación de pantalla» para capturar. Activa Shotjoy en Ajustes del Sistema → Privacidad y seguridad → Grabación de pantalla y vuelve a intentarlo."
        ],
        "Fix Permission…": [
            .traditionalChinese: "修復權限…",
            .japanese: "権限を修復…",
            .french: "Réparer l'autorisation…",
            .spanish: "Reparar permiso…"
        ],
        "Open System Settings": [
            .traditionalChinese: "開啟系統設定",
            .japanese: "システム設定を開く",
            .french: "Ouvrir Réglages Système",
            .spanish: "Abrir Ajustes del Sistema"
        ],
        "Retry": [
            .traditionalChinese: "重試",
            .japanese: "再試行",
            .french: "Réessayer",
            .spanish: "Reintentar"
        ],
        "Cancel": [
            .traditionalChinese: "取消",
            .japanese: "キャンセル",
            .french: "Annuler",
            .spanish: "Cancelar"
        ],
        "Done": [
            .traditionalChinese: "完成",
            .japanese: "完了",
            .french: "Terminé",
            .spanish: "Listo"
        ],
        "Copy": [
            .traditionalChinese: "複製",
            .japanese: "コピー",
            .french: "Copier",
            .spanish: "Copiar"
        ],
        "Save": [
            .traditionalChinese: "儲存",
            .japanese: "保存",
            .french: "Enregistrer",
            .spanish: "Guardar"
        ],
        "Pin": [
            .traditionalChinese: "釘選",
            .japanese: "ピン留め",
            .french: "Épingler",
            .spanish: "Fijar"
        ],
        "Close": [
            .traditionalChinese: "關閉",
            .japanese: "閉じる",
            .french: "Fermer",
            .spanish: "Cerrar"
        ],
        "Copied to clipboard": [
            .traditionalChinese: "已複製到剪貼簿",
            .japanese: "クリップボードにコピーしました",
            .french: "Copié dans le presse-papiers",
            .spanish: "Copiado al portapapeles"
        ],
        "Saved": [
            .traditionalChinese: "已儲存",
            .japanese: "保存しました",
            .french: "Enregistré",
            .spanish: "Guardado"
        ],
        "No text recognized": [
            .traditionalChinese: "沒有辨識到文字",
            .japanese: "文字を認識できませんでした",
            .french: "Aucun texte reconnu",
            .spanish: "No se reconoció texto"
        ],
        "No QR code found": [
            .traditionalChinese: "沒有辨識到 QR Code",
            .japanese: "QR コードが見つかりませんでした",
            .french: "Aucun QR code trouvé",
            .spanish: "No se encontró ningún código QR"
        ],
        "Shortcut Unavailable": [
            .traditionalChinese: "快速鍵無法使用",
            .japanese: "ショートカットを登録できません",
            .french: "Raccourci indisponible",
            .spanish: "Atajo no disponible"
        ],
        "Another app may already own this shortcut. Choose a different combination in Settings, or quit the app that owns it.": [
            .traditionalChinese: "這個快速鍵可能已被其他應用程式占用。請在設定中換一組組合，或結束占用它的應用程式。",
            .japanese: "このショートカットは別のアプリが使用している可能性があります。設定で別の組み合わせに変更するか、使用中のアプリを終了してください。",
            .french: "Une autre app utilise peut-être ce raccourci. Choisissez une autre combinaison dans les réglages ou quittez l'app qui l'utilise.",
            .spanish: "Puede que otra app use este atajo. Elige otra combinación en Ajustes o cierra la app que lo usa."
        ],
        "Shortcut": [
            .traditionalChinese: "快速鍵",
            .japanese: "ショートカット",
            .french: "Raccourci",
            .spanish: "Atajo"
        ],
        "Record": [
            .traditionalChinese: "錄製",
            .japanese: "記録",
            .french: "Définir",
            .spanish: "Grabar"
        ],
        "Press the new shortcut…": [
            .traditionalChinese: "請按下新的快速鍵…",
            .japanese: "新しいショートカットを押してください…",
            .french: "Appuyez sur le nouveau raccourci…",
            .spanish: "Pulsa el nuevo atajo…"
        ],
        "Copy to clipboard after capture": [
            .traditionalChinese: "截圖後自動複製到剪貼簿",
            .japanese: "撮影後にクリップボードへコピー",
            .french: "Copier dans le presse-papiers après la capture",
            .spanish: "Copiar al portapapeles después de capturar"
        ],
        "Play capture sound": [
            .traditionalChinese: "播放截圖音效",
            .japanese: "撮影音を再生",
            .french: "Jouer le son de capture",
            .spanish: "Reproducir sonido de captura"
        ],
        "Automatically save to Desktop": [
            .traditionalChinese: "完成後自動儲存到桌面",
            .japanese: "完了後にデスクトップへ自動保存",
            .french: "Enregistrer automatiquement sur le Bureau",
            .spanish: "Guardar automáticamente en el Escritorio"
        ],
        "Scrolling Capture": [
            .traditionalChinese: "捲動截圖",
            .japanese: "スクロール撮影",
            .french: "Capture défilante",
            .spanish: "Captura con desplazamiento"
        ],
        "Scroll inside the selection, then click Done": [
            .traditionalChinese: "在選取範圍中捲動頁面，完成後按「完成」",
            .japanese: "選択範囲内でスクロールし、完了を押してください",
            .french: "Faites défiler dans la sélection, puis cliquez sur Terminé",
            .spanish: "Desplázate dentro de la selección y pulsa Listo"
        ],
        "Could not stitch: no overlapping region found": [
            .traditionalChinese: "拼接失敗：找不到重疊區域",
            .japanese: "結合できませんでした：重なり合う領域が見つかりません",
            .french: "Impossible d'assembler : aucune zone de chevauchement trouvée",
            .spanish: "No se pudo unir: no se encontró una zona de solapamiento"
        ],
        "Long Screenshot": [
            .traditionalChinese: "長截圖",
            .japanese: "長いスクリーンショット",
            .french: "Capture longue",
            .spanish: "Captura larga"
        ],
        "Recognize": [
            .traditionalChinese: "辨識",
            .japanese: "認識",
            .french: "Reconnaître",
            .spanish: "Reconocer"
        ],
        "AI Face Masking": [
            .traditionalChinese: "AI 人臉打碼",
            .japanese: "AI 顔マスキング",
            .french: "Masquage de visages par IA",
            .spanish: "Enmascarado de caras con IA"
        ],
        "No faces detected": [
            .traditionalChinese: "未偵測到人臉",
            .japanese: "顔が検出されませんでした",
            .french: "Aucun visage détecté",
            .spanish: "No se detectaron caras"
        ],
        "Faces masked": [
            .traditionalChinese: "已為人臉打碼",
            .japanese: "顔をマスキングしました",
            .french: "Visages masqués",
            .spanish: "Caras enmascaradas"
        ],
        "Masking failed": [
            .traditionalChinese: "打碼失敗",
            .japanese: "マスキングに失敗しました",
            .french: "Échec du masquage",
            .spanish: "Error al enmascarar"
        ],
        "Move / Select": [
            .traditionalChinese: "移動 / 選取",
            .japanese: "移動 / 選択",
            .french: "Déplacer / Sélectionner",
            .spanish: "Mover / Seleccionar"
        ],
        "Undo": [
            .traditionalChinese: "復原",
            .japanese: "元に戻す",
            .french: "Annuler l'action",
            .spanish: "Deshacer"
        ],
        "Text": [
            .traditionalChinese: "文字",
            .japanese: "テキスト",
            .french: "Texte",
            .spanish: "Texto"
        ],
        "Mosaic": [
            .traditionalChinese: "馬賽克",
            .japanese: "モザイク",
            .french: "Mosaïque",
            .spanish: "Mosaico"
        ],
        "Brush": [
            .traditionalChinese: "畫筆",
            .japanese: "ブラシ",
            .french: "Pinceau",
            .spanish: "Pincel"
        ],
        "Arrow": [
            .traditionalChinese: "箭頭",
            .japanese: "矢印",
            .french: "Flèche",
            .spanish: "Flecha"
        ],
        "Ellipse": [
            .traditionalChinese: "橢圓",
            .japanese: "楕円",
            .french: "Ellipse",
            .spanish: "Elipse"
        ],
        "Rectangle": [
            .traditionalChinese: "矩形",
            .japanese: "矩形",
            .french: "Rectangle",
            .spanish: "Rectángulo"
        ],
        "Color": [
            .traditionalChinese: "顏色",
            .japanese: "色",
            .french: "Couleur",
            .spanish: "Color"
        ],
        "Drag to select, click a window to capture it; Esc to cancel": [
            .traditionalChinese: "拖曳選取範圍，按一下視窗可直接截圖；Esc 取消",
            .japanese: "範囲をドラッグして選択、ウインドウをクリックすると撮影できます。Esc でキャンセル",
            .french: "Faites glisser pour sélectionner, cliquez une fenêtre pour la capturer ; Échap pour annuler",
            .spanish: "Arrastra para seleccionar, haz clic en una ventana para capturarla; Esc para cancelar"
        ],
        "Screen Recording is managed by macOS; a re-signed build may need a fresh grant.": [
            .traditionalChinese: "螢幕錄製權限由 macOS 管理；重新簽章後可能需要重新授權。",
            .japanese: "画面収録の権限は macOS が管理します。再署名後は再許可が必要な場合があります。",
            .french: "L'enregistrement de l'écran est géré par macOS ; une nouvelle signature peut nécessiter une nouvelle autorisation.",
            .spanish: "La grabación de pantalla la gestiona macOS; una nueva firma puede requerir volver a conceder el permiso."
        ],
        "Screen Recording permission is granted.": [
            .traditionalChinese: "已取得螢幕錄製權限。",
            .japanese: "画面収録の権限があります。",
            .french: "L'autorisation d'enregistrement de l'écran est accordée.",
            .spanish: "Se ha concedido el permiso de grabación de pantalla."
        ],
        "No screenshot yet. Press ⌃⌘A to take one.": [
            .traditionalChinese: "還沒有截圖。按 ⌃⌘A 開始截圖。",
            .japanese: "まだスクリーンショットがありません。⌃⌘A で撮影を開始します。",
            .french: "Aucune capture pour l'instant. Appuyez sur ⌃⌘A pour en prendre une.",
            .spanish: "Aún no hay capturas. Pulsa ⌃⌘A para hacer una."
        ],
        "The screenshot is too long to stitch.": [
            .traditionalChinese: "截圖過長，無法拼接。",
            .japanese: "スクリーンショットが長すぎるため結合できません。",
            .french: "La capture est trop longue pour être assemblée.",
            .spanish: "La captura es demasiado larga para unirla."
        ],
        "A fast, local-only screenshot tool": [
            .traditionalChinese: "快速、純本機的截圖工具",
            .japanese: "高速でローカル完結のスクリーンショットツール",
            .french: "Un outil de capture d'écran rapide et 100 % local",
            .spanish: "Una herramienta de captura de pantalla rápida y totalmente local"
        ],
        "Capture": [
            .traditionalChinese: "截圖",
            .japanese: "撮影",
            .french: "Capture",
            .spanish: "Captura"
        ],
        "Permissions": [
            .traditionalChinese: "權限",
            .japanese: "権限",
            .french: "Autorisations",
            .spanish: "Permisos"
        ],
        "Screen Recording permission granted": [
            .traditionalChinese: "已取得螢幕錄製權限",
            .japanese: "画面収録の権限があります",
            .french: "Autorisation d'enregistrement de l'écran accordée",
            .spanish: "Permiso de grabación de pantalla concedido"
        ],
        "Screen Recording permission not granted": [
            .traditionalChinese: "尚未取得螢幕錄製權限",
            .japanese: "画面収録の権限がありません",
            .french: "Autorisation d'enregistrement de l'écran non accordée",
            .spanish: "Permiso de grabación de pantalla no concedido"
        ],
        "Refresh": [
            .traditionalChinese: "重新整理",
            .japanese: "更新",
            .french: "Actualiser",
            .spanish: "Actualizar"
        ],
        "Default shortcut: ⌃⌘A": [
            .traditionalChinese: "預設快速鍵：⌃⌘A",
            .japanese: "既定のショートカット：⌃⌘A",
            .french: "Raccourci par défaut : ⌃⌘A",
            .spanish: "Atajo predeterminado: ⌃⌘A"
        ],
        "Red": [
            .traditionalChinese: "紅色",
            .japanese: "赤",
            .french: "Rouge",
            .spanish: "Rojo"
        ],
        "Orange": [
            .traditionalChinese: "橙色",
            .japanese: "オレンジ",
            .french: "Orange",
            .spanish: "Naranja"
        ],
        "Yellow": [
            .traditionalChinese: "黃色",
            .japanese: "黄",
            .french: "Jaune",
            .spanish: "Amarillo"
        ],
        "Green": [
            .traditionalChinese: "綠色",
            .japanese: "緑",
            .french: "Vert",
            .spanish: "Verde"
        ],
        "Blue": [
            .traditionalChinese: "藍色",
            .japanese: "青",
            .french: "Bleu",
            .spanish: "Azul"
        ],
        "White": [
            .traditionalChinese: "白色",
            .japanese: "白",
            .french: "Blanc",
            .spanish: "Blanco"
        ],
        "Follow System": [
            .traditionalChinese: "跟隨系統",
            .japanese: "システムに従う",
            .french: "Suivre le système",
            .spanish: "Seguir el sistema"
        ],
        "Language": [
            .traditionalChinese: "語言",
            .japanese: "言語",
            .french: "Langue",
            .spanish: "Idioma"
        ],
        "OK": [
            .traditionalChinese: "好",
            .japanese: "OK",
            .french: "OK",
            .spanish: "OK"
        ]
    ]

    static func text(_ key: String, language: AppLanguage) -> String? {
        table[key]?[language]
    }
}
