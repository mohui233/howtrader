介绍
该网关基于MT5 ZeroMQ连接开发，支持所有MT5交易。

请注意：仅支持对冲模式。
mt5
用户可以按照以下命令通过pip轻松安装。

直接把文件夹解压后放在howtrader\gateway文件夹里

将其保存为 run.py。

from howtrader.event import EventEngine
from howtrader.trader.engine import MainEngine
from howtrader.trader.ui import MainWindow, create_qapp

from howtrader.gateway.mt5 import Mt5Gateway


def main():
    """主入口函数"""
    qapp = create_qapp()

    event_engine = EventEngine()
    main_engine = MainEngine(event_engine)
    main_engine.add_gateway(Mt5Gateway)

    main_window = MainWindow(main_engine, event_engine)
    main_window.showMaximized()

    qapp.exec()


if __name__ == "__main__":
    main()
MT5配置
确保已安装 MT5 客户端并使用模拟账户或真实账户登录（请注意，经纪商提供的账户必须处于对冲模式，净额结算模式将不起作用）。

从mt5目录，找到其中包含的Experts、Include和Libraries文件夹。

从开始菜单启动 MetaEditor。在左侧“导航器”中，找到 MQL5 文件夹，右键单击它并选择“打开文件夹”。将之前解压的三个文件夹复制到该目录中。

返回 MetaEditor，再次右键单击 MQL5 目录，然后单击弹出菜单中的“刷新”按钮。然后点击Experts目录旁边的+按钮，找到vnpy_server.mq5文件，双击打开，点击上方红圈中的绿色播放按钮，执行编译。底部的“Errors”信息栏将显示多条编译消息（确保有0个错误）。

MT5 将弹出 howtrader_server 1.00 的对话框。在对话框中，首先勾选“依赖项”选项卡下的“允许DLL导入”选项，然后切换到“常规”选项卡，勾选“允许算法交易”选项，然后单击“确定”按钮。然后，图表右上角将出现 howtrader_server 的文本提示（字体非常小），右侧有一个小图形图标，该图标应该有一个绿色圆圈（表示它正在运行）。

接下来，点击MT5顶部菜单栏的“工具”->“选项”按钮，打开MT5选项对话框，切换到“EA交易”选项卡，勾选下面所有选项。最后，记得点击“确定”按钮保存设置。这样就完成了MT5上的所有配置工作。

笔记
MT5 禁止适销限价订单。例如，下买单时，订单价格必须低于ask_price_1，否则订单将被拒绝。
使用市价订单进行您希望立即执行的交易。
对于您希望在条件满足时立即触发的止损订单，MT5 提供服务器端止损订单执行（由 Mt5Gateway 支持）。因此，CTA 策略中放置的止损订单将作为服务器端止损订单发出。
注意不要在启动时加载RpcService、RpcGateway、WebService这些需要使用ZeroMQ的应用模块，否则会导致ZeroMQ报错。