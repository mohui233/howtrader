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
