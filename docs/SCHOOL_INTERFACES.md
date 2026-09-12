# 学校接口与验证记录

本文记录 LearnY 实际依赖的逆向协议、2026-09-12 的有界实测，以及尚未验证的边界。URL 构造集中在 `lib/core/api/urls.dart`，协议适配由 `Learn2018Helper`、`IdentityAuthApi`、`RegistrarCalendarApi` 负责。业务仓储依赖 `LearningReadApi`，不应解析学校 HTML 或自行提交密码。

## 会话不能互相代替

| 系统 | 入口与响应 | 成功判断 |
| --- | --- | --- |
| 网络学堂 Learn | `learn.tsinghua.edu.cn`；课程主页、CSRF、JSON API | 认证主页可用，目标读取返回正确数据形状 |
| 统一身份 | `id.tsinghua.edu.cn/do/off/ui/auth/login/form/...`；`checkSingle` 或 `check` | 跟完该服务的重定向／成功页回调，不能仅凭密码 POST 返回 200 |
| OAuth / WebVPN | `oauth.tsinghua.edu.cn`、`webvpn.tsinghua.edu.cn/login` | OAuth state 与 Cookie 属于发起认证的浏览器或 API 会话；不能直接把 API 生成的身份表单 URL 交给另一 Cookie 环境 |
| 教务 | Learn `POST /b/wlxt/common/auth/gnt`，表单 `appId=ALL_ZHJW`；教务 `/j_acegi_login.do?url=/&ticket=...` | 票据交换完成后，目标日期请求返回合法 JSONP |

统一身份的可信设备表单不等于验证码页面。可信设备快捷登录失败后允许一次 SM2 密码提交；学堂和教务共用客户端的提交限流，每账号一分钟最多一次。启用自动登录的凭据验证只创建一个临时客户端、验证一次并释放；超时后不通过新建客户端重置限流快速重复密码。网络超时、5xx 和网络类型变化本身不证明密码失效。

Learn 恢复先尝试身份 Cookie，再使用用户保存的凭据；恢复后更新 CSRF，原请求只重放一次。迟到的旧会话响应复用已完成的恢复。教务单独恢复服务会话，不清除健康的 Learn 会话。“最近学堂恢复”时间仅对应 Learn，不能证明 WebVPN 或教务也已恢复。

本次真实故障链：可信设备登录已成功，成功页链接指向 `https://oauth.tsinghua.edu.cn/thu-oauth/callback`，客户端原先漏接此地址，误报需要验证。接上回调后，首次教务 ticket 又可能落入 HTTP 200 `/sso_fail.jsp`，旧代码误判成功，后续数据请求落入 `/timeout.jsp`。现在两页均分类为授权失败，只换一次教务 ticket；保留已取得的 WebVPN/身份 Cookie，不再次提交密码。

直连与代理比较以实际重定向和响应为准，不能由“开启 V2RayN”直接断言账号失效。WebVPN 转发的内层 `/https/` 可能切成 `/http/`；外层仍是 HTTPS。生产追踪允许的跳转域仅为教务、身份、OAuth 和 WebVPN，每次链有跳数和重试上限。

## 读取接口

以下路径默认位于 `https://learn.tsinghua.edu.cn`；学生路径是当前应用使用范围。

| 能力 | 方法与路径 | 已确认形状／语义 |
| --- | --- | --- |
| 学期列表 | GET `/b/wlxt/kc/v_wlkc_xs_xktjb_coassb/queryxnxq` | 顶层字符串数组，本次 10 个 ID |
| 当前学期 | GET `/b/kc/zhjw_v_code_xnxq/getCurrentAndNextSemester` | `message=success`，`result` 含 `id,xnxq,kssj,jssj`；本次 `resultList` 为空。日期是 Learn 启用范围，不能当教学校历 |
| 选课目录 | GET `/b/wlxt/kc/v_wlkc_xs_xkb_kcb_extend/student/loadCourseBySemesterId/{term}/zh` | `resultList`；新秋季 5 门、历史春季 14 门 |
| 每门排课 | GET `/b/kc/v_wlkc_xk_sjddb/detail?id={course}` | 数组；上述课程全部成功读取。失败保留旧排课，成功空数组才清除 |
| 通知 | POST `/b/wlxt/kcgg/wlkc_ggb/student/pageListXsbyWgq` 与 `...Ygq` | 未过期、已过期两组；`object.aaData`，正文 `ggnr` 为 Base64；有附件时补读 `beforeViewXs` 页面 |
| 作业 | POST `/b/wlxt/kczy/zy/student/zyListWj`、`zyListYjwg`、`zyListYpg` | 未交、已交未批、已批三组；`object.aaData`；`xszyid` 与作业定义 `zyid` 不可混用 |
| 作业补充 | GET `/f/wlxt/kczy/zy/student/viewCj`；POST `/b/wlxt/kczy/zy/student/detail`（`id=zyid`） | HTML 提交／附件详情及 API 正文；本次抽样作业要求和批改反馈可读。优秀作业 `yxzylist` 为可选补充 |
| 课程文件 | GET `/b/wlxt/kj/wlkc_kjxxb/student/kjxxbByWlkcidAndSizeForStudent` | 参数 `wlkcid,size`，`object` 数组；本次 13 条。`size=1` 确实只返回 1 条 |
| 文件分类 | GET `/b/wlxt/kj/wlkc_kjflb/student/pageList?wlkcid=...` | `object.rows`，带 `page,total,records`；当前用于补充分类名称 |
| 文件下载 | GET `/b/wlxt/kj/wlkc_kjxxb/student/downloadFile?sfgk=0&wjid=...`；作业附件 `/b/wlxt/kczy/zy/student/downloadFile/{course}/{attachment}` | 课程文件实测成功；可能忽略 Range 返回 200，诊断仅消费前 4096 字节后取消流 |
| 教务日历 | GET `https://zhjw.cic.tsinghua.edu.cn/jxmh_out.do` | `m=bks_jxrl_all`、`p_start_date/p_end_date=YYYYMMDD`、`jsoncallback`；JSONP 数组含 `nq,nr,kssj,jssj,dd,fl`。研究生变体为 `yjs_jxrl_all` |
| 个人信息 | GET 课程主页，由 `getUserInfo` 解析 HTML | 实际用于个人页与登录接入；与学生列表一起复用 Learn 认证 |

2026-09-12 使用生产客户端请求 2026-09-14 至 2027-01-17，获得 **75 条**教务事件，后续周事件延续到 12 月 31 日。请求整学期有效；并不代表用户每周都应有课，也不代表已发布全部考试。已知教学范围一次获取后按周缓存，同学期翻周共享请求；未知／跨多个学期的日期窗口保留按绝对周查询。

应用按成功请求的日期范围保存教务覆盖，而非仅记录返回事件所在日。范围内空日、空周均禁止叠加网络学堂排课推算，以保留放假和调课结果；后续离线不撤销覆盖。只有尚未成功取得教务范围的日期可以退化到排课推算。完整的缓存兼容与历史保护规则见 [SCHEDULE_DESIGN.md](SCHEDULE_DESIGN.md)。

## 列表完整性

通知／作业 POST 使用 multipart `aoData`（JSON 数组），课程项为 `{name: wlkcid, value: ...}`。实测 `iDisplayStart=0,iDisplayLength=1` 得 1 条通知，`iTotalDisplayRecords="2"`；不传分页项时该样本返回全部 2 条。总数可能是字符串。

`school_list_loader.dart` 统一验证列表形状和总数，仅在确有剩余时继续按 offset 取页。重复页、总数变化、缺失数组或提前空页会失败，避免局部结果作为权威删除集合；最多 50 页。课程文件从 size 200 开始，满额时翻倍取全，最多 12800；达到上限仍满额则报错保留缓存。正常小课程不会增加请求。超大课程或学校以后增加隐含硬上限尚未生产验证，不能宣称所有历史课程已逐条核验。

文件列表解析丢行或缺少身份字段会使整个读取失败，不把残缺列表交给同步删除。通知／作业附件和正文的可选补充仍可能部分失败；本次非空样本读取成功，但未来需要显式的“详情不完整”状态时应扩充读取契约，不能用默认空值冒充删除。

## 文件、图片与会话失效

Learn 会在 HTTP 200 下返回“登录超时”或带 401/403 的错误面板。API、HTML 图片和文件下载共用 `session_page_detection.dart`，按页面结构识别。普通 HTML 附件、课程正文里的“统一身份认证”文字或 `location.href` 不触发密码恢复。

CSRF 只添加到精确的 Learn HTTPS 主机；每次重试从客户端重新取 token。当前实测课程下载在未显式附 CSRF 时也成功，不能声称该参数始终必需。实测一个 `application/msword` 响应实际有 ZIP 文件头，另一个 PDF 有 `%PDF` 文件头；MIME 不足以单独确定文件类型。预览继续使用本地 pdfrx/ZIP 引擎，学校 `beforePlay` URL 保留为模型兼容信息，不承担主预览。

文件发布和预览生命周期见 [FILE_STORAGE.md](FILE_STORAGE.md)。正文图片仅抽样寻找，当前非空样本没有可探测图片；图片过期恢复以脱敏页面结构回归验证，未宣称完成真机端到端测试。

## 写入与保留接口的边界

实际应用写入包括作业提交 `POST .../student/tjzy`、文件收藏 `GET /b/xt/wlkc_xsscb/student/add|delete`、退出登录。HTTP GET 不代表只读，探测工具不能按方法自动判断安全。此次没有向学校提交／删除作业、切换收藏或更改阅读状态。

讨论、答疑、问卷、教师分支、分类内文件列表、收藏列表／置顶、备注、远端课程排序、语言切换以及 `getAllContents` 保留在兼容 API 层，没有当前产品调用入口；不据其存在宣称已支持或已生产验证。文件分类列表是 `getFileList` 的内部依赖，不在未使用范围内。学生与教师接口后续新增调用者时，应先核对相应角色的实际响应。

## 可复现证据

诊断入口与参数见 [tool/auth_diag/README.md](../tool/auth_diag/README.md)。本轮仅一次真实密码提交；后续全部复用独立 Cookie 快照，密码预算为零。原应用 Cookie 和凭据存储未改写。

本地未跟踪日志：`output/campus-build25-recovery.log`（漏接回调）、`campus-build25-recovered.log`（教务失败页）、`campus-build25-term.log`（整学期）、`school-build25-dense-contracts.log`（内容与下载）、`school-build25-pagination.log`（分页参数）。日志不提交账号内容、Cookie、票据或正文。真实设备的网络切换与交互仍由设备验收确认；这些记录说明协议探测范围，不是学校接口的长期可用性保证。
