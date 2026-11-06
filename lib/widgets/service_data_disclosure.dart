import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/privacy_screen.dart';

/// Shared by the first purchase, subscription management and VPN connection.
/// Versioned separately from the old VPN-permission introduction.
class ServiceDataDisclosure {
  static const acceptedKey = 'service_data_disclosure_accepted_v2';

  static Future<bool> ensureAccepted(BuildContext context) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(acceptedKey) == true) return true;
      if (!context.mounted) return false;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog.adaptive(
          title: const Text('数据使用与隐私'),
          scrollable: true,
          content: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('购买或使用 VPN 前，请了解以下数据用途。'),
              SizedBox(height: 12),
              Text(
                  '账号与用量：皮卡云处理登录邮箱、身份凭证、套餐、流量用量及连接配置，用于身份验证、提供线路、计量额度和维护服务。密码不保存在本机。'),
              SizedBox(height: 12),
              Text('VPN：开启后，设备网络流量经你选择的线路传输。仅在你主动连接后工作，可随时断开；不读取设备 GPS。'),
              SizedBox(height: 12),
              Text(
                  'Apple 购买：Apple 处理付款，皮卡云验证并保存交易标识、商品、币种、金额、有效期及账号绑定，用于开通、恢复、对账、续订和退款处理。购买尝试及结果也会记录，以恢复中断的购买；不获取 Apple 账号密码或银行卡资料。'),
              SizedBox(height: 12),
              Text(
                  'IP 与地图：IP 检测会将查询 IP 发送至 ipwho.is（备用 ipapi.co），地图向 OpenStreetMap 请求图块；不附带皮卡云登录凭证，本地查询历史不上传。'),
              SizedBox(height: 12),
              Text('数据不用于广告或跨应用跟踪，不出售 VPN 服务数据。必要交易资料按适用要求保留；可在“我的”发起账户删除。'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const PrivacyScreen())),
              child: const Text('完整隐私说明'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('暂不使用'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('知悉并继续'),
            ),
          ],
        ),
      );
      if (accepted != true) return false;
      // Don't proceed on a failed persistence operation: show it again next time.
      return await preferences.setBool(acceptedKey, true);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('无法读取隐私确认状态，请稍后重试')));
      }
      return false;
    }
  }
}
