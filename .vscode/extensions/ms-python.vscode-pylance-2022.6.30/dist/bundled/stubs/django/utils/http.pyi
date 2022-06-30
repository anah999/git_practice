from typing import Any, Iterable, List, Optional, Pattern, Tuple, Union

ETAG_MATCH: Pattern[str]
MONTHS: List[str]
RFC1123_DATE: Pattern[str]
RFC850_DATE: Pattern[str]
ASCTIME_DATE: Pattern[str]
RFC3986_GENDELIMS: str
RFC3986_SUBDELIMS: str

def urlquote(url: str, safe: str = ...) -> str: ...
def urlquote_plus(url: str, safe: str = ...) -> str: ...
def urlunquote(quoted_url: str) -> str: ...
def urlunquote_plus(quoted_url: str) -> str: ...
def urlencode(query: Any, doseq: bool = ...) -> str: ...
def http_date(epoch_seconds: Optional[float] = ...) -> str: ...
def parse_http_date(date: str) -> int: ...
def parse_http_date_safe(date: str) -> Optional[int]: ...
def base36_to_int(s: str) -> int: ...
def int_to_base36(i: int) -> str: ...
def urlsafe_base64_encode(s: bytes) -> str: ...
def urlsafe_base64_decode(s: str) -> bytes: ...
def parse_etags(etag_str: str) -> List[str]: ...
def quote_etag(etag_str: str) -> str: ...
def is_same_domain(host: str, pattern: str) -> bool: ...
def url_has_allowed_host_and_scheme(
    url: Optional[str], allowed_hosts: Optional[Union[str, Iterable[str]]], require_https: bool = ...
) -> bool: ...
def is_safe_url(
    url: Optional[str], allowed_hosts: Optional[Union[str, Iterable[str]]], require_https: bool = ...
) -> bool: ...
def parse_qsl(
    qs: str,
    keep_blank_values: bool = ...,
    strict_parsing: bool = ...,
    encoding: str = ...,
    errors: str = ...,
    max_num_fields: Optional[int] = ...,
    separator: str = ...,
) -> List[Tuple[str, str]]: ...
def escape_leading_slashes(url: str) -> str: ...
