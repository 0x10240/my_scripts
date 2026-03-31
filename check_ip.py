import requests


class IPInfoError(Exception):
    pass


def fetch_ipinfo_raw(ip: str) -> dict:
    """
    调 IPinfo (widget/demo) 接口，返回原始 JSON 数据字典。
    如果请求失败或返回格式异常，会抛 IPInfoError。
    """
    url = f"https://ipinfo.io/widget/demo/{ip}"
    try:
        resp = requests.get(url, timeout=10)
    except requests.RequestException as e:
        raise IPInfoError(f"request failed: {e}")

    if resp.status_code != 200:
        raise IPInfoError(f"bad status code: {resp.status_code}")

    try:
        data = resp.json()
    except ValueError as e:
        raise IPInfoError(f"invalid JSON: {e}")

    # 简单检查结构
    if "data" not in data:
        raise IPInfoError("unexpected response structure (no 'data' field)")

    return data["data"]


def classify_ip_type(ip: str) -> dict:
    """
    使用 IPinfo 判断 IP 类型是机房还是家宽。

    返回示例：
    {
        "ip": "1.2.3.4",
        "ip_type": "datacenter",     # 或 "residential" / "other"
        "reason": "asn.type=hosting or company.type=hosting",
        "asn_type": "hosting",
        "company_type": "business",
        "privacy": {
            "proxy": False,
            "vpn": False,
            "tor": False,
            "hosting": True,
        }
    }
    """
    data = fetch_ipinfo_raw(ip)

    asn = data.get("asn") or {}
    company = data.get("company") or {}
    privacy = data.get("privacy") or {}

    asn_type = (asn.get("type") or "").lower()
    company_type = (company.get("type") or "").lower()

    is_hosting_flag = bool(privacy.get("hosting"))
    is_proxy = bool(privacy.get("proxy"))
    is_vpn = bool(privacy.get("vpn"))
    is_tor = bool(privacy.get("tor"))

    # ---- 判定逻辑（可以按需微调）----

    # 1) 明确机房 / 云服务器
    if (
        asn_type == "hosting"
        or company_type == "hosting"
        or is_hosting_flag
    ):
        ip_type = "datacenter"
        reason = "asn.type=hosting or company.type=hosting or privacy.hosting=true"

    # 2) 有 proxy / VPN / Tor 但不是 hosting，优先当成非家宽（算机房/出口节点）
    elif is_proxy or is_vpn or is_tor:
        ip_type = "datacenter"
        reason = "privacy.proxy/vpn/tor indicates exit node"

    # 3) 典型家宽 / 运营商线路
    elif asn_type in ("isp", "residential") or company_type in ("isp", "residential"):
        ip_type = "residential"
        reason = "asn/company type indicates ISP/residential"

    # 4) 其余类型（business, education, government, unknown…）
    else:
        ip_type = "other"
        reason = f"asn.type={asn_type}, company.type={company_type}"

    return {
        "ip": ip,
        "ip_type": ip_type,  # "datacenter" / "residential" / "other"
        "reason": reason,
        "asn_type": asn_type,
        "company_type": company_type,
        "privacy": {
            "proxy": is_proxy,
            "vpn": is_vpn,
            "tor": is_tor,
            "hosting": is_hosting_flag,
        },
    }


if __name__ == "__main__":
    # 示例：自己出口 IP，可以先用别的服务查出来再传进来
    test_ip = "37.59.57.181"
    try:
        result = classify_ip_type(test_ip)
        print(f"IP: {result['ip']}")
        print(f"类型: {result['ip_type']}  (机房=datacenter, 家宽=residential)")
        print(f"原因: {result['reason']}")
        print(f"ASN 类型: {result['asn_type']}")
        print(f"公司类型: {result['company_type']}")
        print("隐私信息:", result["privacy"])
    except IPInfoError as e:
        print("检测失败:", e)
