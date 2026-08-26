import Foundation

nonisolated enum AppConstants {
    nonisolated enum Common {
        static let requiredFieldMarker = "*"
        static let cancel = "取消"
        static let confirm = "确定"
        static let edit = "编辑"
        static let delete = "删除"
        static let save = "保存"
        static let error = "错误"
        static let emDash = "—"
        static let itemSeparator = " · "
    }

    nonisolated enum Application {
        static let displayName = "DESMG Utilities"
        static let launcherWindowID = "launcher"
        static let subTrackWindowID = "subtrack"
        static let authenticatorWindowID = "authenticator"
        static let codexWindowID = "codex-context"
        static let subTrackName = "订阅管理"
        static let authenticatorName = "身份验证器"
        static let codexName = "Codex Context"
        static let loadingSubTrack = "正在载入订阅管理…"

        static let launcherMinimumWidth = 980.0
        static let launcherMinimumHeight = 430.0
        static let subTrackMinimumWidth = 980.0
        static let subTrackMinimumHeight = 680.0
        static let authenticatorMinimumWidth = 400.0
        static let authenticatorMinimumHeight = 500.0
        static let codexMinimumWidth = 920.0
        static let codexMinimumHeight = 620.0
    }

    nonisolated enum Launcher {
        static let projectURL = "https://github.com/jyxjjj/PC-OS-Utils"
        static let shortVersionKey = "CFBundleShortVersionString"
        static let buildVersionKey = "CFBundleVersion"
        static let versionFormat = "Version %@ (%@)"
        static let title = "小工具"
        static let subtitle = "选择要启动的工具。"
        static let gitHubLogoAsset = "GitHubLogo"
        static let subTrackTitle = "订阅管理"
        static let subTrackDescription = "管理订阅、到期提醒与支出预测。"
        static let authenticatorTitle = "身份验证器"
        static let authenticatorDescription = "管理本地加密的 TOTP 验证码。"
        static let codexTitle = "Codex Context"
        static let codexDescription = "查看 Codex task、SubAgent 与 token 使用情况。"
        static let license = "GNU Affero General Public License v3.0"
        static let launch = "启动"

        static let outerSpacing = 26.0
        static let titleSpacing = 8.0
        static let logoSize = 24.0
        static let logoPadding = 8.0
        static let cardContainerSpacing = 18.0
        static let footerSpacing = 24.0
        static let footerMinimumSpacer = 12.0
        static let contentPadding = 34.0
        static let topPadding = 16.0
        static let gradientBlueOpacity = 0.2
        static let cardContentSpacing = 14.0
        static let cardMinimumSpacer = 4.0
        static let cardPadding = 22.0
        static let cardMinimumHeight = 234.0
        static let cardCornerRadius = 18.0
    }

    nonisolated enum Codex {
        static let bookmarkKey = "CodexSessionsDirectoryBookmark"
        static let directoryName = ".codex"
        static let sessionIndexFile = "session_index.jsonl"
        static let allowedSessionDirectories = ["archived_sessions", "sessions"]
        static let refreshInterval = 10.0
        static let warningThreshold = 0.6
        static let dangerThreshold = 0.8
        static let sidebarMinimumWidth = 260.0
        static let sidebarIdealWidth = 320.0
        static let unreadableFilesMaximumHeight = 180.0
        static let detailMaximumWidth = 760.0
        static let statusIndicatorSize = 8.0

        static let authorizationTitle = "选择 ~/.codex 目录"
        static let authorizationDescription = "请选择 ~/.codex；应用读取 session_index.jsonl、sessions 和 archived_sessions。"
        static let directorySelectionFailed = "目录选择失败"
        static let accessDenied = "无法访问已授权的 ~/.codex 目录，请重新选择。"
        static let invalidDirectory = "只能选择当前用户的 %@ 目录\n当前选择的文件夹：%@"
        static let cannotEnumerate = "无法枚举 Codex sessions 目录。"
        static let loadFailed = "无法载入 Codex session 索引"
        static let noSessions = "没有 Codex session"
        static let noSessionsDescription = "session_index.jsonl 中没有可读取的对话索引。"
        static let chooseDirectory = "选择目录"
        static let refresh = "刷新"
        static let mainTasks = "Main Tasks"
        static let subagents = "SubAgent"
        static let unreadableFiles = "%d 个 JSONL 文件无法载入"
        static let missingFileAttributes = "无法读取文件属性"
        static let missingSessionMetadata = "缺少有效 session metadata"
        static let invalidSessionFileName = "JSONL 文件名格式无效"
        static let sessionFileNotFound = "找不到所选对话的 Session JSONL 文件"
        static let selectSession = "选择一个 session"
        static let currentContext = "当前 Context"
        static let contextUsed = "已使用 %@ Tokens"
        static let contextRemaining = "剩余 %@ / %@ Tokens"
        static let notAvailable = "N/A"
        static let wholeSession = "整个 Session 总计"
        static let lastTurn = "最近一轮"
        static let tokenComposition = "Token 构成"
        static let totalComposition = "总 Token：输入 / 输出"
        static let inputComposition = "输入构成"
        static let outputComposition = "输出构成"
        static let input = "输入"
        static let cachedInput = "缓存输入"
        static let cacheWrite = "缓存写入"
        static let uncachedInput = "非缓存输入"
        static let output = "输出"
        static let reasoning = "推理"
        static let regularOutput = "非推理输出"
        static let total = "总计"
        static let sessionDetails = "Session 详情"
        static let status = "状态"
        static let model = "Model"
        static let reasoningEffort = "推理强度"
        static let role = "角色"
        static let workingDirectory = "工作目录"
        static let unloaded = "未加载"
        static let completedTurns = "已完成轮次"
        static let duration = "累计耗时"
        static let averageTTFT = "平均 TTFT"
        static let lastActivity = "最后活动"
        static let parseErrors = "JSONL 解析错误"
        static let running = "运行中"
        static let completed = "已完成"
        static let interrupted = "已中断"
        static let shutdown = "已关闭"
    }

    nonisolated enum Authenticator {
        static let minimumDigits = 6
        static let maximumDigits = 8
        static let defaultDigits = 6
        static let minimumPeriod = 15
        static let maximumPeriod = 60
        static let periodStep = 15
        static let defaultPeriod = 30
        static let supportedPeriods = [15, 30, 45, 60]
        static let labelSeparator: Character = ":"

        nonisolated enum Store {
            static let modelConfigurationName = "Authenticator"
            static let keySize = 32
            static let saltSize = 16
            static let derivationMilliseconds: UInt32 = 250
            static let authenticationFailed = "密钥错误或加密数据已损坏"
            static let duplicateEntries = "存在重复的身份验证器账户"
            static let encryptionFailed = "无法加密身份验证器数据"
            static let invalidOrder = "身份验证器账户顺序无效"
            static let invalidParameters = "身份验证器加密参数无效"
            static let invalidStore = "身份验证器存储数据无效"
            static let keyDerivationFailed = "无法派生 AES-256 加密密钥"
            static let emptyKey = "密钥不能为空"
            static let locked = "身份验证器尚未解锁"
            static let missingEntry = "找不到身份验证器账户"
        }

        nonisolated enum OTPAuth {
            static let scheme = "otpauth"
            static let host = "totp"
            static let pathPrefix = "/"
            static let servicePathFormat = "/%@"
            static let accountPathFormat = "/%@:%@"
            static let secretQueryName = "secret"
            static let issuerQueryName = "issuer"
            static let algorithmQueryName = "algorithm"
            static let digitsQueryName = "digits"
            static let periodQueryName = "period"
            static let lineSeparator = "\n"
            static let maximumFileSize = 1_048_576
            static let codeFormat = "%0*d"
            static let invalidURI = "OTP Auth URI 无效"
            static let missingSecret = "URI 中缺少密钥"
            static let missingAccount = "URI 中缺少账户名称"
            static let invalidLabel = "服务名称和用户名不能包含冒号"
            static let invalidAlgorithm = "OTP Auth URI 的算法无效"
            static let invalidDigits = "OTP Auth URI 的位数必须为 6 到 8"
            static let invalidPeriod = "OTP Auth URI 的周期必须为 15、30、45 或 60 秒"
            static let duplicateParameterFormat = "OTP Auth URI 包含重复参数: \"%@\""
            static let missingParameterValueFormat = "OTP Auth URI 参数缺少值: \"%@\""
            static let invalidAccount = "无法创建 OTP Auth URI"
            static let fileTooLarge = "导入文件不能超过 1 MiB"
            static let invalidEncoding = "导入文件必须是 UTF-8 文本"
            static let noAccounts = "导入文件中不包含 OTP Auth URI"
            static let duplicateAccount = "导入文件包含重复或已存在的账户"
        }

        nonisolated enum State {
            static let entryNotFound = "未找到账户"
            static let invalidOrder = "账户排序数据无效"
            static let emptyServiceName = "服务名称不能为空"
            static let invalidLabel = "服务名称和用户名不能包含冒号"
            static let invalidParameters = "验证码位数或周期无效"
        }

        nonisolated enum Base32 {
            static let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
            static let padding: Character = "="
            static let emptySecret = "Base32 密钥不能为空"
            static let invalidCharacterFormat = "无效的 Base32 字符: \"%@\""
            static let nonASCII = "Base32 密钥只能包含 ASCII 字符"
            static let invalidLength = "Base32 密钥长度无效"
            static let invalidPadding = "Base32 填充格式无效"
            static let nonZeroPaddingBits = "Base32 密钥包含非零填充位"
        }

        nonisolated enum Unlock {
            static let unavailable = "身份验证器不可用"
            static let retry = "重试"
            static let unlocking = "正在解锁…"
            static let creatingStore = "正在创建加密存储…"
            static let unlockTitle = "解锁身份验证器"
            static let setupTitle = "设置身份验证器密钥"
            static let configuredDescription = "密钥仅保留在内存中，关闭身份验证器后需要重新输入。"
            static let setupDescription = "数据将使用 AES-256-GCM 加密。密钥遗失后无法恢复。"
            static let keyPrompt = "输入密钥"
            static let confirmationPrompt = "再次输入密钥"
            static let unlock = "解锁"
            static let createAndLaunch = "创建并启动"
            static let mismatchedKeys = "两次输入的密钥不一致"

            static let progressPadding = 24.0
            static let progressCornerRadius = 12.0
            static let contentSpacing = 18.0
            static let titleSpacing = 6.0
            static let fieldsSpacing = 12.0
            static let maximumContentWidth = 320.0
            static let contentPadding = 36.0
        }

        nonisolated enum List {
            static let refreshInterval = 1.0
            static let title = "身份验证器"
            static let lock = "锁定"
            static let export = "导出账户"
            static let `import` = "导入账户"
            static let addAccount = "添加账户"
            static let deleteTitle = "删除账户？"
            static let deleteMessageFormat = "将永久删除 \"%@\" 的验证码账户。此操作无法撤销。"
            static let emptyTitle = "暂无账户"
            static let emptyDescription = "添加账户以生成验证码。"
        }

        nonisolated enum Row {
            static let rowSpacing = 12.0
            static let verticalPadding = 6.0
            static let iconOpacity = 0.15
            static let iconSize = 40.0
            static let infoSpacing = 2.0
            static let codeSpacing = 8.0
            static let expirationThreshold = 5.0
            static let trackOpacity = 0.2
            static let timerLineWidth = 3.0
            static let groupedCodeFormat = "%@ %@"
            static let rotationDegrees = -90.0
            static let animationDuration = 1.0
            static let timerSize = 28.0
            static let copyButtonWidth = 20.0
            static let copyFeedbackSeconds = 2.0
        }

        nonisolated enum Editor {
            static let addTitle = "添加账户"
            static let editTitle = "编辑账户"
            static let accountSection = "账户信息"
            static let servicePrompt = "例如 GitHub"
            static let serviceName = "服务名称"
            static let username = "用户名或备注"
            static let invalidServiceName = "服务名称不能为空"
            static let serviceNameContainsSeparator = "服务名称不能包含冒号"
            static let usernameContainsSeparator = "用户名不能包含冒号"
            static let secretSection = "密钥"
            static let useURI = "使用 otpauth:// URI"
            static let uri = "otpauth:// URI"
            static let paste = "粘贴"
            static let parse = "解析"
            static let base32Secret = "Base32 密钥"
            static let generate = "生成"
            static let optionsSection = "选项"
            static let algorithm = "算法"
            static let digitsFormat = "位数: %d"
            static let periodFormat = "周期: %d 秒"
            static let saveChanges = "保存更改"
            static let saving = "正在保存…"

            static let requiredFieldSpacing = 0.0
            static let contentSpacing = 0.0
            static let width = 540.0
            static let addMinimumHeight = 360.0
            static let editMinimumHeight = 300.0
            static let addIdealHeight = 620.0
            static let editIdealHeight = 420.0
            static let progressPadding = 20.0
            static let progressCornerRadius = 12.0
        }

        nonisolated enum Transfer {
            static let exportTitle = "导出账户"
            static let importTitle = "导入账户"
            static let close = "关闭"
            static let exportDescription = "将完整的 otpauth:// URI 导出为 UTF-8 文本"
            static let importDescription = "从包含 otpauth:// URI 的 UTF-8 文本导入账户"
            static let secretWarning = "导出内容包含明文 TOTP 密钥"
            static let export = "导出"
            static let `import` = "导入"
            static let importing = "正在导入…"
            static let exportFilename = "身份验证器账户.txt"
            static let exportSucceeded = "导出成功"
            static let importSucceededFormat = "导入成功，新增 %d 个账户"

            static let stackSpacing = 0.0
            static let contentSpacing = 20.0
            static let descriptionSpacing = 8.0
            static let descriptionOpacity = 0.08
            static let descriptionCornerRadius = 8.0
            static let width = 440.0
            static let height = 300.0
            static let progressPadding = 24.0
            static let progressCornerRadius = 12.0
        }
    }

    nonisolated enum SubTrack {
        static let modelConfigurationName = "SubTrack"
        static let databaseUnavailable = "订阅管理数据库不可用"
        static let defaultCurrency = "CNY"
        static let defaultReminderDays = 30
        static let currencyCodes = ["CNY", "EUR", "SGD", "TWD", "HKD", "USD", "JPY"]

        nonisolated enum Rules {
            static let decimalScale = 2
            static let maximumNameLength = 120
            static let maximumCategoryLength = 80
            static let maximumChannelLength = 120
            static let maximumNotesLength = 3_000
            static let minimumExtensionDays = 1
            static let maximumExtensionDays = 36_500
            static let minimumReminderDays = 0
            static let maximumReminderDays = 3_650
            static let minimumMoney: Decimal = 0
            static let maximumMoney: Decimal = 1_000_000_000
            static let defaultForecastMonths = 6
            static let minimumForecastMonths = 1
            static let maximumForecastMonths = 24
            static let forecastDays = 90
            static let monthsPerYear = 12
            static let firstDayOfMonth = 1
            static let nextDayOffset = 1
            static let monthKeyFormat = "%04d-%02d"

            static let invalidName = "名称不能为空且不能超过 120 个字符"
            static let invalidCategory = "分类不能为空且不能超过 80 个字符"
            static let invalidChannel = "购买渠道不能超过 120 个字符"
            static let invalidNotes = "备注不能超过 3000 个字符"
            static let unsupportedCurrency = "请选择支持的币种"
            static let invalidExtensionDays = "单次续费天数需介于 1 和 36500 天之间"
            static let invalidReminderDays = "提前提醒天数需介于 0 和 3650 天之间"
            static let officialPrice = "官方价格"
            static let thirdPartyPrice = "第三方参考价"
            static let invalidDateCalculation = "无法计算当前日期与到期日期之间的天数"
            static let lowerPriceKind = "官方价格与第三方参考价中的较低值"
            static let thirdPartyReferenceKind = "第三方参考价"
            static let officialPriceKind = "官方价格"
            static let unsetPriceKind = "尚未设置价格"
            static let invalidMoneyFormat = "%@需介于 0 和 1000000000 之间"
        }

        nonisolated enum Model {
            static let essentialPriority = "刚需"
            static let highPriority = "高频"
            static let normalPriority = "普通"
            static let lowPriority = "低频"
            static let activeStatus = "有效"
            static let dueSoonStatus = "即将到期"
            static let expiredStatus = "已到期"
        }

        nonisolated enum State {
            static let updatedNotice = "项目已更新"
            static let createdNotice = "项目已创建"
            static let deletedNotice = "项目已删除"
        }

        nonisolated enum Formatting {
            static let editorLocale = "en_US_POSIX"
            static let currencyLocale = "zh_CN"
            static let editorDateFormat = Date.VerbatimFormatStyle(
                format: "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",
                locale: Locale(identifier: editorLocale),
                timeZone: .current,
                calendar: Calendar(identifier: .gregorian)
            )
            static let minimumFractionDigits = 0
            static let maximumFractionDigits = 2
            static let cardPadding = 16.0
            static let cardCornerRadius = 12.0
            static let cardLineWidth = 1.0
        }

        nonisolated enum Editor {
            static let date = "日期"
            static let dateFieldSpacing = 6.0
            static let requiredFieldSpacing = 0.0
            static let dateFieldWidth = 92.0
            static let invalidExtensionDaysInteger = "单次续费天数必须是整数"
            static let invalidReminderDaysInteger = "提前提醒天数必须是整数"
            static let basicInformation = "基本信息"
            static let name = "名称"
            static let categoryPrompt = "域名 / 服务器 / 软件 / 会员"
            static let category = "分类"
            static let expirationDate = "到期日期"
            static let extensionDays = "单次续费天数"
            static let priority = "优先级"
            static let purchaseChannel = "购买渠道"
            static let notes = "备注"
            static let priceAndReminder = "价格与提醒"
            static let currency = "币种"
            static let officialPrice = "官方价格"
            static let thirdPartyPrice = "第三方参考价"
            static let reminderDays = "提前提醒天数"
            static let addTitle = "新增项目"
            static let editTitle = "编辑项目"
            static let discardChangesTitle = "放弃未保存的更改？"
            static let continueEditing = "继续编辑"
            static let discard = "放弃"
            static let currencyChangeTitle = "切换币种会清空金额"
            static let changeAndClear = "切换并清空"
            static let noCurrencyConversion = "订阅管理功能不会自动换汇。"
            static let subscriptionNotesMinimumLines = 3
            static let subscriptionNotesMaximumLines = 8
            static let subscriptionMinimumWidth = 600.0
            static let subscriptionMinimumHeight = 360.0
            static let subscriptionIdealHeight = 640.0
        }

        nonisolated enum Content {
            static let loadFailed = "无法载入数据"
            static let createDatabaseFailed = "无法创建订阅管理数据库"
            static let retry = "重试"
            static let noticeMilliseconds: Int64 = 3_500
            static let noticeHorizontalPadding = 18.0
            static let noticeVerticalPadding = 11.0
            static let noticeBottomPadding = 18.0
            static let noticeAnimationDuration = 0.2
            static let sectionSpacing = 18.0
            static let sidebarWidth = 350.0
            static let contentPadding = 22.0
            static let maximumContentWidth = 1_480.0
            static let title = "订阅管理"
            static let newProject = "新建项目"
            static let metricMinimumWidth = 190.0
            static let metricGridSpacing = 14.0
            static let metricCardSpacing = 8.0
            static let projectsContentSpacing = 14.0
            static let subscriptionRowSpacing = 14.0
            static let activeProjects = "有效项目"
            static let activeProjectsNote = "当前无需处理"
            static let dueSoonProjects = "即将到期"
            static let dueSoonProjectsNote = "已进入提醒窗口"
            static let expiredProjects = "已到期"
            static let expiredProjectsNote = "需要续费或删除"
            static let next90Days = "未来 90 天"
            static let noExpenses = "暂无支出"
            static let totalsByCurrency = "按币种独立汇总"
            static let searchPrompt = "搜索名称、分类、渠道或备注"
            static let allPriorities = "全部优先级"
            static let subscriptions = "订阅项目"
            static let sortedResultFormat = "按到期日排序 · %d 个结果"
            static let projectMetadataFormat = "%@ · %@ · %@"
            static let noProjects = "还没有项目"
            static let noProjectsDescription = "创建项目后，可在这里查看到期日期和续费预测。"
            static let createProject = "创建项目"
            static let noMatches = "没有符合条件的项目"
            static let noMatchesDescription = "当前优先级范围内没有项目。"
            static let clearFilter = "清除筛选"
            static let emptyMinimumHeight = 220.0
            static let rowSpacing = 10.0
            static let projectTitleSpacing = 2.0
            static let metricTitleOpacity = 0.8
            static let metricLineLimit = 2
            static let metricMinimumScale = 0.68
            static let metricNoteOpacity = 0.72
            static let metricMinimumHeight = 88.0
            static let metricPadding = 16.0
            static let metricBackgroundOpacity = 0.11
            static let metricCornerRadius = 12.0
            static let rowIconSize = 38.0
            static let rowIconOpacity = 0.15
            static let rowIconCornerRadius = 9.0
            static let rowTitleSpacing = 4.0
            static let prioritySpacing = 7.0
            static let priorityHorizontalPadding = 6.0
            static let priorityVerticalPadding = 3.0
            static let priceSpacing = 4.0
            static let statusHorizontalPadding = 8.0
            static let statusVerticalPadding = 5.0
            static let statusOpacity = 0.12
            static let menuSize = 32.0
            static let rowPadding = 12.0
            static let rowCornerRadius = 10.0
            static let deleteTitleFormat = "删除 \"%@\"？"
            static let deleteProject = "删除项目"
            static let deleteFailedFormat = "删除失败: %@"
            static let deleteDescription = "项目数据将永久删除，此操作无法撤销。"
            static let expiredDaysFormat = "过期 %d 天"
            static let remainingDaysFormat = "剩余 %d 天"
            static let reminders = "提醒"
            static let noReminders = "暂无提醒"
            static let reminderCardSpacing = 12.0
            static let expiredTitleFormat = "%@ 已到期"
            static let dueSoonTitleFormat = "%@ 即将到期"
            static let overdueDescriptionFormat = "已过期 %d 天，请续费或删除项目。"
            static let dueSoonDescriptionFormat = "还剩 %d 天，到期日为 %@。"
            static let nextSixMonths = "未来 6 个月"
            static let noForecast = "暂无可预测支出"
            static let forecastCardSpacing = 12.0
            static let forecastEmptyMinimumHeight = 120.0
            static let chartMonth = "月份"
            static let chartAmount = "金额"
            static let chartCurrency = "币种"
            static let chartHeight = 160.0
        }

        nonisolated enum Detail {
            static let contentSpacing = 18.0
            static let contentPadding = 22.0
            static let maximumWidth = 980.0
            static let headerSpacing = 18.0
            static let iconSize = 58.0
            static let iconOpacity = 0.15
            static let iconCornerRadius = 13.0
            static let titleSpacing = 6.0
            static let unsetChannel = "未设置渠道"
            static let projectMetadataFormat = "%@ · %@ · %@"
            static let metadataSpacing = 10.0
            static let statusHorizontalPadding = 8.0
            static let statusVerticalPadding = 4.0
            static let statusOpacity = 0.12
            static let priceSpacing = 4.0
            static let projectConfiguration = "项目配置"
            static let gridMinimumWidth = 220.0
            static let gridSpacing = 12.0
            static let renewalPeriod = "单次续费"
            static let reminder = "提前提醒"
            static let daysFormat = "%d 天"
            static let officialPrice = "官方价格"
            static let thirdPartyPrice = "第三方参考价"
            static let unset = "未设置"
            static let rowSpacing = 3.0
        }
    }
}
