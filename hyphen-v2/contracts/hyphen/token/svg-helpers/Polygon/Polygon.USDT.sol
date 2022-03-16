// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "../SvgHelperBase.sol";

contract PolygonUSDT is SvgHelperBase {
    using Strings for uint256;

    constructor(uint256 _decimals) SvgHelperBase(_decimals) {}

    function getTokenSvg(
        uint256 _tokenId,
        uint256 _suppliedLiquidity,
        uint256 _totalSuppliedLiquidity
    ) public view virtual override returns (string memory) {
        string memory tokenId = _tokenId.toString();
        string memory suppliedLiquidity = _divideByPowerOf10(_suppliedLiquidity, tokenDecimals, 3);
        string memory sharePercent = _calculatePercentage(_suppliedLiquidity, _totalSuppliedLiquidity);
        return
            string(
                abi.encodePacked(
                    '<svg version="1.1" id="prefix__Layer_1" xmlns="http://www.w3.org/2000/svg" x="0" y="0" viewBox="0 0 405 405" xml:space="preserve"><style>.prefix__st2{fill:#fff}.prefix__st19{font-family:&apos;Courier&apos;}.prefix__st20{font-size:24px}</style><radialGradient id="prefix__SVGID_1_" cx="1.388" cy="-50" r="1" gradientTransform="matrix(0 327.499 327.499 0 16577.465 -454.476)" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#8247e5"/><stop offset="1"/></radialGradient><path d="M30 0h345c16.57 0 30 13.43 30 30v345c0 16.57-13.43 30-30 30H30c-16.57 0-30-13.43-30-30V30C0 13.43 13.43 0 30 0z" fill="url(#prefix__SVGID_1_)"/><radialGradient id="prefix__SVGID_00000050633384941599449990000003968045424753684663_" cx="1.677" cy="-50" r="1" gradientTransform="matrix(0 270.995 167.538 0 8579.416 -376.976)" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#fff"/><stop offset=".711" stop-color="#50af95"/><stop offset="1" stop-opacity="0"/><stop offset="1" stop-opacity="0"/></radialGradient><path d="M214.93 95.88c-5.94-8.8-18.93-8.8-24.87 0-43.56 64.49-70.9 107.33-70.9 149.07 0 45.6 37.28 82.55 83.33 82.55s83.33-36.95 83.33-82.55c.01-41.74-27.33-84.58-70.89-149.07z" fill="url(#prefix__SVGID_00000050633384941599449990000003968045424753684663_)"/><path class="prefix__st2" d="M271.41 338.62a.8.8 0 00-.59-.24h-1.66a.8.8 0 00-.59.24.8.8 0 00-.24.59v5c0 .11-.02.22-.06.32-.04.1-.1.2-.18.27a.8.8 0 01-.59.24h-8.33c-.11 0-.22-.02-.32-.06s-.2-.1-.27-.18-.14-.17-.18-.27a.866.866 0 01-.06-.32v-5a.8.8 0 00-.24-.59.8.8 0 00-.59-.24h-1.67c-.22 0-.43.09-.59.24s-.24.37-.24.59v15a.8.8 0 00.24.59.8.8 0 00.59.24h1.67a.8.8 0 00.59-.24.8.8 0 00.24-.59v-5a.8.8 0 01.24-.59.8.8 0 01.59-.24h8.33a.8.8 0 01.59.24.8.8 0 01.24.59v5c0 .11.02.22.06.32.04.1.1.2.18.27s.17.14.27.18.21.06.32.06h1.66c.11 0 .22-.02.32-.06.1-.04.2-.1.27-.18s.14-.17.18-.27c.04-.1.06-.21.06-.32v-15c0-.11-.02-.22-.06-.32-.04-.11-.1-.2-.18-.27zM321.41 341.91a.8.8 0 00-.59-.24h-5.83v.04h-2.5a.8.8 0 01-.59-.24.8.8 0 01-.24-.59v-5a.8.8 0 00-.24-.59.8.8 0 00-.59-.24h-1.66c-.11 0-.22.02-.32.06-.1.04-.2.1-.27.18a.8.8 0 00-.24.59v18.33c0 .11.02.22.06.32.04.1.1.2.18.27a.8.8 0 00.59.24h1.66c.11 0 .22-.02.32-.06.1-.04.2-.1.27-.18a.8.8 0 00.24-.59v-8.33a.8.8 0 01.24-.59.8.8 0 01.59-.24h5a.8.8 0 01.59.24.8.8 0 01.24.59v8.33c0 .11.02.22.06.32.04.1.1.2.18.27a.8.8 0 00.59.24h1.66c.11 0 .22-.02.32-.06.1-.04.2-.1.27-.18a.8.8 0 00.24-.59v-11.7c0-.11-.02-.22-.06-.32a.624.624 0 00-.17-.28zM338.08 341.91a.8.8 0 00-.59-.24h-11.67c-.11 0-.22.02-.32.06a.98.98 0 00-.27.18.8.8 0 00-.24.59v11.66a.8.8 0 00.24.59.8.8 0 00.59.24h11.67a.8.8 0 00.59-.24.8.8 0 00.24-.59v-1.66c0-.11-.02-.22-.06-.32-.04-.1-.1-.2-.18-.27a.8.8 0 00-.59-.24h-8.33c-.22 0-.43-.09-.59-.24-.16-.16-.24-.37-.24-.59s.09-.43.24-.59c.16-.16.37-.24.59-.24h8.33a.8.8 0 00.59-.24.8.8 0 00.24-.59v-6.66c0-.11-.02-.22-.06-.32a.841.841 0 00-.18-.29zm-3.16 4.24a.8.8 0 01-.18.27.8.8 0 01-.59.24h-5a.8.8 0 01-.59-.24.8.8 0 01-.24-.59.8.8 0 01.24-.59.8.8 0 01.59-.24h5a.8.8 0 01.59.24.8.8 0 01.24.59c0 .11-.02.22-.06.32zM354.74 341.91a.8.8 0 00-.59-.24l-2.5.04h-9.17a.8.8 0 00-.59.24.8.8 0 00-.24.59v11.66c0 .11.02.22.06.32.04.1.1.2.18.27a.8.8 0 00.59.24h1.67a.8.8 0 00.59-.24.8.8 0 00.24-.59v-8.33a.8.8 0 01.24-.59.8.8 0 01.59-.24h5c.11 0 .22.02.32.06.1.04.2.1.27.18a.8.8 0 01.24.59v8.33c0 .11.02.22.06.32.04.1.1.2.18.27a.8.8 0 00.59.24h1.67a.8.8 0 00.59-.24.8.8 0 00.24-.59v-11.7c0-.11-.02-.22-.06-.32a.65.65 0 00-.17-.27zM288.08 341.91a.8.8 0 00-.59-.24h-1.67c-.11 0-.22.02-.32.06a.98.98 0 00-.27.18.8.8 0 00-.24.59v8.33a.8.8 0 01-.24.59.8.8 0 01-.59.24h-5c-.11 0-.22-.02-.32-.06-.1-.04-.2-.1-.27-.18a.8.8 0 01-.24-.59v-8.33c0-.11-.02-.22-.06-.32-.04-.1-.1-.2-.18-.27a.8.8 0 00-.59-.24h-1.67c-.11 0-.22.02-.32.06a.98.98 0 00-.27.18.8.8 0 00-.24.59v11.66a.8.8 0 00.24.59.8.8 0 00.59.24h8.34c.22 0 .43.09.59.24.16.16.24.37.24.59s-.09.43-.24.59c-.16.16-.37.24-.59.24h-5c-.11 0-.22.02-.32.06s-.2.1-.27.18-.14.17-.18.27c-.04.1-.06.21-.06.32v1.66c0 .11.02.22.06.32.04.1.1.2.18.27s.17.14.27.18.21.06.32.06h8.33a.8.8 0 00.59-.24.8.8 0 00.24-.59v-16.66c0-.11-.02-.22-.06-.32-.05-.08-.12-.17-.19-.25zM304.74 341.91a.8.8 0 00-.59-.24h-11.67a.8.8 0 00-.59.24.8.8 0 00-.24.59v16.66c0 .11.02.22.06.32.04.1.1.2.18.27a.8.8 0 00.59.24h1.67a.8.8 0 00.59-.24.8.8 0 00.24-.59v-3.33a.8.8 0 01.24-.59.8.8 0 01.59-.24h8.34a.8.8 0 00.59-.24.8.8 0 00.24-.59v-11.66a.866.866 0 00-.24-.6zm-3.09 8.93a.8.8 0 01-.52.77c-.1.04-.21.06-.32.06h-5a.8.8 0 01-.59-.24.8.8 0 01-.24-.59v-5a.8.8 0 01.24-.59.8.8 0 01.59-.24h5a.866.866 0 01.6.24.8.8 0 01.24.59v5zM329.97 96.59c.28 0 .57-.05.83-.16s.5-.27.7-.47a2.116 2.116 0 00.63-1.53V81.49a2.182 2.182 0 00-.62-1.52 2.105 2.105 0 00-1.52-.63h-4.31c-.57 0-1.12.23-1.52.63-.4.4-.63.95-.63 1.52v4.31c0 .28-.05.57-.16.83s-.27.5-.47.7a2.116 2.116 0 01-1.53.63h-4.31c-.28 0-.57-.05-.83-.16s-.5-.27-.7-.47a2.116 2.116 0 01-.63-1.53V64.24c0-.28.05-.57.16-.83s.27-.5.47-.7a2.116 2.116 0 011.53-.63h1.25c.42 0 .84-.12 1.2-.36.35-.24.63-.57.79-.97a2.138 2.138 0 00-.49-2.33l-7.68-7.76c-.2-.21-.44-.37-.7-.48a2.124 2.124 0 00-1.66 0c-.26.11-.5.27-.7.48l-7.72 7.76c-.3.3-.51.68-.59 1.09s-.04.85.12 1.24.43.73.78.96c.35.24.76.37 1.19.37h1.25c.29 0 .57.05.83.16s.5.27.7.47c.2.2.36.44.47.7.11.26.16.55.16.83v30.2c0 .28.05.57.16.83s.27.5.47.7a2.116 2.116 0 001.53.63h21.55z"/><path class="prefix__st2" d="M324.14 70.08a2.116 2.116 0 001.53.63h4.31c.28 0 .57-.05.83-.16s.5-.27.7-.47a2.116 2.116 0 00.63-1.53v-4.31c0-.28.05-.57.16-.83s.27-.5.47-.7a2.116 2.116 0 011.53-.63h4.32c.28 0 .57.05.83.16s.5.27.7.47c.2.2.36.44.47.7.11.26.16.55.16.83v21.57c0 .28-.05.57-.16.83s-.27.5-.47.7a2.116 2.116 0 01-1.53.63h-1.26c-.42 0-.84.13-1.2.36-.35.24-.63.57-.79.97-.16.39-.2.83-.11 1.24.09.42.3.8.6 1.1l7.73 7.72c.2.2.44.37.7.48a2.124 2.124 0 002.36-.48l7.72-7.72c.3-.3.5-.69.58-1.1.08-.42.04-.85-.12-1.24a2.12 2.12 0 00-.79-.96c-.35-.24-.77-.36-1.19-.36h-1.29c-.28 0-.57-.05-.83-.16s-.5-.27-.7-.47a2.116 2.116 0 01-.63-1.53V55.6c0-.28-.05-.57-.16-.83s-.27-.5-.47-.7c-.2-.2-.44-.36-.7-.47-.26-.11-.55-.16-.83-.16h-21.57c-.28 0-.57.05-.83.16s-.5.27-.7.47a2.116 2.116 0 00-.63 1.53v12.95c0 .28.05.57.16.83s.27.5.47.7z"/><text transform="translate(73.686 67)" class="prefix__st2 prefix__st19 prefix__st20">',
                    suppliedLiquidity,
                    ' USDT</text><text transform="rotate(-90 213.61 143.092)" class="prefix__st2 prefix__st19 prefix__st20">',
                    sharePercent,
                    '%</text><path fill="none" stroke="#fff" stroke-miterlimit="10" d="M61.86 267.12V114.71"/><text transform="translate(79.915 355)" class="prefix__st2 prefix__st19" font-size="10">ID: ',
                    tokenId,
                    '</text><g fill-rule="evenodd" clip-rule="evenodd"><path d="M54.8 51.18l-3.1 6.51a.14.14 0 00.03.15l8.37 8.02c.05.05.13.05.18 0l8.37-8.02c.04-.04.05-.1.03-.15l-3.1-6.51a.136.136 0 00-.11-.07H54.91c-.05-.01-.09.02-.11.07z" fill="#50af95"/><path d="M61.26 58.36c-.06 0-.37.02-1.06.02-.55 0-.94-.02-1.08-.02-2.13-.09-3.72-.46-3.72-.91 0-.44 1.59-.81 3.72-.91v1.45c.14.01.54.03 1.09.03.66 0 .99-.03 1.05-.03v-1.45c2.12.09 3.71.47 3.71.91s-1.59.81-3.71.91zm0-1.97v-1.3h2.97v-1.98h-8.07v1.98h2.96v1.3c-2.41.11-4.22.59-4.22 1.16s1.81 1.05 4.22 1.16v4.15h2.14v-4.15c2.4-.11 4.21-.59 4.21-1.16s-1.8-1.05-4.21-1.16zm0 0" fill="#fff"/></g><path d="M128.52 77.23H56.69c-2.76 0-5 2.24-5 5v7.47c0 2.76 2.24 5 5 5h71.83c2.76 0 5-2.24 5-5v-7.47c0-2.76-2.24-5-5-5z" fill="#8247e5"/><text transform="translate(56.685 89.706)" class="prefix__st2" font-size="12" font-family="Courier-Bold">ON POLYGON</text></svg>'
                )
            );
    }

    function getChainName() public pure override returns (string memory) {
        return "Polygon";
    }
}
