#coding=utf-8

import autoit

from wrapper import log_call, log_call_error
from interface import Interface
from tdx import TDX
from expt import InitError, ParseError
import tools, monitor

from datetime import datetime
import time, traceback, winsound, codecs, json

#==================================================================

BROKER = 'DongBei'
ACCOUNTS = ['QJ8']
LOCAL_BASE_DIR = 'c:\\logs\\autohook\\stock\\dongbei'
EXPORT_BASE_DIR = '\\\\192.168.1.66\\public\\hotdata\\stock\\dongbei'
#LOCAL_BASE_DIR = 'c:\\logs\\autohook\\stock\\test'
#EXPORT_BASE_DIR = '\\\\192.168.1.66\\public\\hotdata\\stock\\test'

#==================================================================

class DongBeiTDX(TDX):
    def __init__(self, broker, account, local_base_dir, export_base_dir):
        super(DongBeiTDX, self).__init__(broker, account, local_base_dir, export_base_dir)
        self.wid_prompt = u'[CLASS:#32770; TITLE:提示]'
        self.cid_prompt_ok = '[CLASS:Button; INSTANCE:1]'
        self.cid_buy_code = '[CLASS:Edit; INSTANCE:1]'
        self.cid_buy_price = '[CLASS:Edit; INSTANCE:2]'
        self.cid_buy_volume = '[CLASS:Edit; INSTANCE:5]'
        self.cid_buy_entrust = '[CLASS:Button; INSTANCE:32]'
        self.cid_buy_able = '[CLASS:Static; INSTANCE:29]'
        self.cid_sell_code = '[CLASS:Edit; INSTANCE:15]'
        self.cid_sell_price = '[CLASS:Edit; INSTANCE:16]'
        self.cid_sell_volume = '[CLASS:Edit; INSTANCE:19]'
        self.cid_sell_entrust = '[CLASS:Button; INSTANCE:55]'
        self.cid_sell_able = '[CLASS:Static; INSTANCE:121]'        
        self.cid_cancel_refresh = '[CLASS:Button; INSTANCE:73]'
        self.cid_cancel_selectall = '[CLASS:Button; INSTANCE:75]'
        self.cid_cancel_do = '[CLASS:Button; INSTANCE:72]'
        self.wid_export = u'[CLASS:#32770; TITLE:输出]'
        self.cid_export_edit = '[CLASS:Edit; INSTANCE:1]'
        self.cid_export_ok = '[CLASS:Button; INSTANCE:9]'
        self.cid_property_refresh = '[CLASS:Button; INSTANCE:33]'
        self.cid_property_export = '[CLASS:Button; INSTANCE:39]'
        self.cid_entrust_refresh = '[CLASS:Button; INSTANCE:79]'
        self.cid_entrust_export = '[CLASS:Button; INSTANCE:85]'
        self.cid_trade_refresh = '[CLASS:Button; INSTANCE:125]'
        self.cid_trade_export = '[CLASS:Button; INSTANCE:131]'

#==================================================================

class DongBeiInterface(DongBeiTDX, Interface):
    def __init__(self, account):
        if account not in ACCOUNTS:
            raise InitError('account %s is not registered' % (account))
        super(DongBeiInterface, self).__init__(BROKER, account, LOCAL_BASE_DIR, EXPORT_BASE_DIR)

#------------------------------------------------------------------

    def get_reg_accounts(self):
        return ACCOUNTS[:]

#------------------------------------------------------------------

    def buy(self, code, price, volume):
        return self._entrust_1('b', code, price, volume)

#------------------------------------------------------------------

    def sell(self, code, price, volume):
        return self._entrust_1('s', code, price, volume)

#------------------------------------------------------------------

    def cancel_all(self):
        return self._cancel_all()

#------------------------------------------------------------------

    def get_balance(self, **kwargs):
        if 'day' in kwargs:
            return self._get_balance_byday(kwargs['day'])
        else:
            return self._get_balance_today()

#------------------------------------------------------------------

    def get_position(self, **kwargs):
        if 'day' in kwargs:
            return self._get_position_byday(kwargs['day'])
        else:
            return self._get_position_today()

#------------------------------------------------------------------

    def get_entrust(self, **kwargs):
        if 'day' in kwargs:
            return self._get_entrust_byday(kwargs['day'])
        else:
            return self._get_entrust_today()

#------------------------------------------------------------------

    def get_filled_result(self, **kwargs):
        if 'day' in kwargs:
            return self._get_traded_byday(kwargs['day'])
        else:
            return self._get_traded_today()

#==================================================================

class DongBeiService(DongBeiTDX):
    def __init__(self, account):
        if account not in ACCOUNTS:
            raise InitError('account %s is not registered' % (account))
        super(DongBeiService, self).__init__(BROKER, account, LOCAL_BASE_DIR, EXPORT_BASE_DIR)

#------------------------------------------------------------------

    def get_reg_accounts(self):
        return ACCOUNTS[:]

#------------------------------------------------------------------

    @log_call_error
    def _export(self, type):
        ret_code = -1
        ret_value = None
        error_msg = ''
        if type == 'property':
            cid_refresh = self.cid_property_refresh
            cid_export = self.cid_property_export
            export_path = self.src_property_path
        elif type == 'entrust':
            cid_refresh = self.cid_entrust_refresh
            cid_export = self.cid_entrust_export
            export_path = self.src_entrust_path
        elif type == 'trade':
            cid_refresh = self.cid_trade_refresh
            cid_export = self.cid_trade_export
            export_path = self.src_trade_path
        else:
            error_msg = 'invalid type : %s' % (type)
            return (ret_code, ret_value, error_msg, self.export_log_path)        
        ret_code = 1
        try:
            autoit.control_click(self.wid_main, cid_refresh)
            time.sleep(5)
            autoit.control_click(self.wid_main, cid_export)
            if autoit.win_wait(self.wid_export, timeout=3) == 1:
                ret_code = 2
                autoit.win_activate(self.wid_export)
                autoit.control_set_text(self.wid_export, self.cid_export_edit, export_path)
                autoit.control_click(self.wid_export, self.cid_export_ok)
                if autoit.win_wait(self.wid_notepad, timeout=5) == 1:
                    ret_code = 3
                    autoit.win_close(self.wid_notepad)
                    ret_code = 0
        except autoit.AutoItError:
            error_msg = traceback.format_exc()
        return (ret_code, ret_value, error_msg, self.export_log_path)

#------------------------------------------------------------------

    @log_call_error
    def _parse_property(self):
        ret_code = -1
        ret_value = None
        error_msg = ''

        src_path = self.src_property_path
        fund_path = self.dst_fund_path
        position_path = self.dst_position_path

        src_file = None
        fund_file = None
        position_file = None

        try:
            src_file = codecs.open(src_path, 'r', 'gbk')
            fund_file = open(fund_path, 'w')
            position_file = open(position_path, 'w')
        except IOError:
            if src_file : src_file.close()
            if fund_file : fund_file.close()
            if position_file : position_file.close()
            error_msg = traceback.format_exc()
            return (ret_code, ret_value, error_msg, self.export_log_path)

        ret_code = 1

        try:
            for line in src_file:
                if len(line) < 50 or line.find(u'证券代码') == 0 or line.find(u'没有相应的查询信息!') != -1: 
                    continue
                elif line.find('--------') == 0:
                    ret_code = 2
                elif line.find(u'人民币') == 0:
                    out = {}
                    tokens = line.strip().split(':')
                    out['rc'] = tokens[2].split()[0]
                    out['ac'] = tokens[3].split()[0]
                    out['mv'] = tokens[5].split()[0]
                    out['ta'] = tokens[6].split()[0]
                    fund_file.write(json.dumps(out) + u'\n')
                else:
                    out = {}
                    tokens = list(filter(lambda x : x != '', map(unicode.strip, line.strip().split('     '))))
                    out['sc'] = tokens[0]
                    out['vo'] = tokens[2].split('.')[0]
                    out['av'] = tokens[3].split('.')[0]
                    position_file.write(json.dumps(out) + u'\n')
            position_file.close()
            fund_file.close()
            src_file.close()
            ret_code = 0
        except IOError:
            ret_code = 3
            error_msg = traceback.format_exc()            
        except ParseError:
            ret_code = 4
            error_msg = traceback.format_exc()
        return (ret_code, ret_value, error_msg, self.export_log_path)

#------------------------------------------------------------------

    @log_call_error
    def _parse_entrust(self):
        ret_code = -1
        ret_value = None
        error_msg = ''

        src_path = self.src_entrust_path
        dst_path = self.dst_entrust_path

        src_file = None
        dst_file = None

        try:
            src_file = codecs.open(src_path, 'r', 'gbk')
            dst_file = open(dst_path, 'w')
        except IOError:
            if src_file : src_file.close()
            if dst_file : dst_file.close()
            error_msg = traceback.format_exc()
            return (ret_code, ret_value, error_msg, self.export_log_path)

        ret_code = 1

        try:
            for line in src_file:
                if len(line) < 50 or line.find('-------') == 0 or line.find(u'委托时间') == 0 or \
                    line.find(u'没有相应的查询信息!') != -1:
                    continue
                else:
                    out = {}
                    tokens = list(filter(lambda x : x != '', map(unicode.strip, line.strip().split('     '))))
                    out['sc'] = tokens[1]
                    token = tokens[3]
                    if token == u'买入':
                        out['ot'] = 'b'
                    elif token == u'卖出':
                        out['ot'] = 's'
                    #elif token == u'配售':
                    #    out['ot'] = 'x'
                    else:
                        raise ParseError('invalid bs : %s' % (line))
                    out['pr'] = tokens[6]
                    out['vo'] = tokens[7].split('.')[0]
                    out['tp'] = tokens[9]
                    out['tv'] = tokens[10].split('.')[0]
                    out['on'] = tokens[8]
                    token = tokens[5]
                    if token == u'已报' or token == u'待报':
                        out['st'] = '0'
                    elif token == u'废单':
                        out['st'] = '5'
                    elif token == u'部成':
                        out['st'] = '3'
                    elif token == u'已成':
                        out['st'] = '1'
                    elif token == u'部撤':
                        out['st'] = '4'
                    elif token == u'已撤':
                        out['st'] = '2'
                    else:
                        raise ParseError('invalid status : %s' % (line))
                    dst_file.write(json.dumps(out) + u'\n')
            src_file.close()
            dst_file.close()
            ret_code = 0
        except IOError:
            ret_code = 2
            error_msg = traceback.format_exc()
        except ParseError:
            ret_code = 3
            error_msg = traceback.format_exc()
        return (ret_code, ret_value, error_msg, self.export_log_path)

#------------------------------------------------------------------

    @log_call_error
    def _parse_trade(self):
        ret_code = -1
        ret_value = None
        error_msg = ''

        src_path = self.src_trade_path
        dst_path = self.dst_trade_path

        src_file = None
        dst_file = None

        try:
            src_file = codecs.open(src_path, 'r', 'gbk')
            dst_file = open(dst_path, 'w')
        except IOError:
            if src_file : src_file.close()
            if dst_file : dst_file.close()
            error_msg = traceback.format_exc()
            return (ret_code, ret_value, error_msg, self.export_log_path)

        ret_code = 1

        try:
            for line in src_file:
                if len(line) < 50 or line.find('-------') == 0 or line.find(u'成交时间') == 0 or\
                    line.find(u'没有相应的查询信息!') != -1:
                    continue
                else:
                    out = {}
                    tokens = list(filter(lambda x : x != '', map(unicode.strip, line.strip().split('     '))))
                    out['ts'] = tokens[0]
                    token = tokens[3]
                    if token == u'买入':
                        out['ot'] = 'b'
                    elif token == u'卖出':
                        out['ot'] = 's'
                    #elif token == u'配售':
                    #    out['ot'] = 'x'
                    else:
                        raise ParseError('invalid bs : %s' % (line))
                    out['fp'] = tokens[4]
                    out['fv'] = tokens[5].split('.')[0]
                    out['on'] = tokens[8]
                    out['sc'] = tokens[1]
                    dst_file.write(json.dumps(out) + u'\n')
            src_file.close()
            dst_file.close()
            ret_code = 0
        except IOError:
            ret_code = 2
            error_msg = traceback.format_exc()
        except ParseError:
            ret_code = 3
            error_msg = traceback.format_exc()
        return (ret_code, ret_value, error_msg, self.export_log_path)

#==================================================================