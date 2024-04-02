import os
import datetime
import pandas as pd
import ccxt
import time

from howtrader.trader.database import BaseDatabase, get_database
from howtrader.trader.object import BarData
from howtrader.trader.object import Exchange, Interval
from typing import Dict, List
import pytz

# 获取本地时区
local_tz = pytz.timezone('Asia/Shanghai')

pd.set_option('expand_frame_repr', False)

okx_limit_count = 100  # 分页返回的结果集数量，最大为100
okx_rate_limit = 20  # 限速：20次/2s

# API初始化
key = ''
secret = ''
passphrase = ''


database: BaseDatabase = get_database()


def get_bars(df) -> List[BarData]:
    buf: Dict[datetime, BarData] = {}

    # 将open_time列中的Unix时间戳转换为本地时区的时间
    df['datetime'] = pd.to_datetime(df['open_time'], unit='ms').dt.tz_localize('UTC').dt.tz_convert(local_tz)

    # 移除'open_time'列
    df.drop(columns=['open_time'], inplace=True)

    # df.set_index('datetime', inplace=True)

    for index, row in df.iterrows():
        bar: BarData = BarData(
            symbol="BTC-USDT",  # 现货
            # symbol="BTC-USDT-SWAP",  # 合约
            exchange=Exchange.OKX,
            datetime=row['datetime'],
            interval=Interval.MINUTE,
            volume=float(row['volume']),
            open_price=float(row['open']),
            high_price=float(row['high']),
            low_price=float(row['low']),
            close_price=float(row['close']),
            gateway_name="OKX"
        )
        buf[bar.datetime] = bar

    index: List[datetime] = list(buf.keys())
    index.sort()
    history: List[BarData] = [buf[i] for i in index]
    return history


def crawl_okx_data(symbol, start_time, end_time):
    """
    爬取 Binance 交易所数据的方法.
    :param symbol: 请求的 symbol: like BTC/USDT, ETH/USD等。
    :param start_time: like 2018-1-1
    :param end_time: like 2019-1-1
    :return:
    """
    okx = ccxt.okx({
        'proxies': {'http': 'http://127.0.0.1:7890', 'https': 'http://127.0.0.1:7890'},
        'key': key,
        'secret': secret,
        'passphrase': passphrase,
        'timeout': 15000,
        'enableRateLimit': True
    })

    current_path = os.getcwd()
    file_dir = os.path.join(current_path, 'okx', symbol.replace('/', ''))

    if not os.path.exists(file_dir):
        os.makedirs(file_dir)

    start_time = datetime.datetime.strptime(start_time, '%Y-%m-%d')
    end_time = datetime.datetime.strptime(end_time, '%Y-%m-%d')

    start_time_stamp = int(start_time.timestamp()) * 1000
    end_time_stamp = int(end_time.timestamp()) * 1000

    while True:
        try:
            # print(start_time_stamp)

            data = okx.fetch_ohlcv(symbol, timeframe='1m', since=start_time_stamp, limit=okx_limit_count)
            df = pd.DataFrame(data)

            df.rename(columns={0: 'open_time', 1: 'open', 2: 'high', 3: 'low', 4: 'close', 5: 'volume'}, inplace=True)

            df = df.assign(turnover=0.0, open_interest=0.0)  # 添加两列

            # print(df)

            start_time_stamp = int(df.iloc[-1]['open_time'])  # 获取下一个次请求的时间.

            # filename = str(start_time_stamp) + '.csv'
            # save_file_path = os.path.join(file_dir, filename)

            # print("文件保存路径为：%s" % save_file_path)
            # exit()
            bars = get_bars(df)
            if bars:
                database.save_bar_data(bars)

            # df.set_index('open_time', drop=True, inplace=True)

            if start_time_stamp > end_time_stamp:
                print("完成数据的请求.")
                break

            if len(df) < okx_limit_count:
                print("数据量不够了")
                break

            # 控制请求速率
            time.sleep(2 / okx_rate_limit)

        except Exception as error:
            print(error)
            time.sleep(10)



def sample_data_vnpy_data(exchange_name, symbol):
    path = os.path.join(os.getcwd(), exchange_name, symbol.replace('/', ''))
    print(f"the data path = {path}")

    file_paths = [os.path.join(path, file) for root, dirs, files in os.walk(path) for file in files if file.endswith('.csv')]
    file_paths = sorted(file_paths)

    all_df = pd.concat((pd.read_csv(file) for file in file_paths), ignore_index=True)
    all_df['open_time'] = all_df['open_time'].apply(lambda x: (x // 60) * 60)
    all_df['datetime'] = pd.to_datetime(all_df['open_time'], unit='ms') + pd.Timedelta(hours=8)

    all_df['high'] = all_df[['open', 'high', 'low', 'close']].max(axis=1)
    all_df['low'] = all_df[['open', 'high', 'low', 'close']].min(axis=1)

    all_df.drop_duplicates(subset=['open_time'], inplace=True)
    all_df.set_index('datetime', inplace=True)

    print("*" * 20)

    all_df.to_csv(path + '_vnpy.csv')

    print(all_df)


def main():
    symbol = "BTC-USDT"  # 现货
    # symbol = "BTC-USDT-SWAP"  # 合约
    crawl_okx_data(symbol, "2019-01-01", "2024-03-30")
    # sample_data_vnpy_data('okx', symbol)


if __name__ == '__main__':
    main()
