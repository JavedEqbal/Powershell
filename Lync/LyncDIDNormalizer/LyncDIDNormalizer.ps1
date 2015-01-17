function New-Popup {
    param (
        [Parameter(Position=0,Mandatory=$True,HelpMessage="Enter a message for the popup")]
        [ValidateNotNullorEmpty()]
        [string]$Message,
        [Parameter(Position=1,Mandatory=$True,HelpMessage="Enter a title for the popup")]
        [ValidateNotNullorEmpty()]
        [string]$Title,
        [Parameter(Position=2,HelpMessage="How many seconds to display? Use 0 require a button click.")]
        [ValidateScript({$_ -ge 0})]
        [int]$Time=0,
        [Parameter(Position=3,HelpMessage="Enter a button group")]
        [ValidateNotNullorEmpty()]
        [ValidateSet("OK","OKCancel","AbortRetryIgnore","YesNo","YesNoCancel","RetryCancel")]
        [string]$Buttons="OK",
        [Parameter(Position=4,HelpMessage="Enter an icon set")]
        [ValidateNotNullorEmpty()]
        [ValidateSet("Stop","Question","Exclamation","Information" )]
        [string]$Icon="Information"
    )

    #convert buttons to their integer equivalents
    switch ($Buttons) {
        "OK"               {$ButtonValue = 0}
        "OKCancel"         {$ButtonValue = 1}
        "AbortRetryIgnore" {$ButtonValue = 2}
        "YesNo"            {$ButtonValue = 4}
        "YesNoCancel"      {$ButtonValue = 3}
        "RetryCancel"      {$ButtonValue = 5}
    }

    #set an integer value for Icon type
    switch ($Icon) {
        "Stop"        {$iconValue = 16}
        "Question"    {$iconValue = 32}
        "Exclamation" {$iconValue = 48}
        "Information" {$iconValue = 64}
    }

    #create the COM Object
    Try {
        $wshell = New-Object -ComObject Wscript.Shell -ErrorAction Stop
        #Button and icon type values are added together to create an integer value
        $wshell.Popup($Message,$Time,$Title,$ButtonValue+$iconValue)
    }
    Catch {
        Write-Warning "Failed to create Wscript.Shell COM object"
        Write-Warning $_.exception.message
    }
}

function Set-ClipBoard{
  param(
    [string]$text
  )
  process{
    Add-Type -AssemblyName System.Windows.Forms
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Multiline = $true
    $tb.Text = $text
    $tb.SelectAll()
    $tb.Copy()
  }
}

function Get-FileFromDialog {
    # Example: 
    #  $fileName = Get-FileFromDialog -fileFilter 'CSV file (*.csv)|*.csv' -titleDialog "Select A CSV File:"
    [CmdletBinding()] 
    param (
        [Parameter(Position=0)]
        [string]$initialDirectory = './',
        [Parameter(Position=1)]
        [string]$fileFilter = 'All files (*.*)| *.*',
        [Parameter(Position=2)] 
        [string]$titleDialog = '',
        [Parameter(Position=3)] 
        [switch]$AllowMultiSelect=$false
    )
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = $fileFilter
    $OpenFileDialog.Title = $titleDialog
    $OpenFileDialog.ShowHelp = if ($Host.name -eq 'ConsoleHost') {$true} else {$false}
    if ($AllowMultiSelect) { $openFileDialog.MultiSelect = $true } 
    $OpenFileDialog.ShowDialog() | Out-Null
    if ($AllowMultiSelect) { return $openFileDialog.Filenames } else { return $openFileDialog.Filename }
}

function Save-FileFromDialog {
    # Example: 
    #  $fileName = Save-FileFromDialog -defaultfilename 'backup.csv' -titleDialog 'Backup to a CSV file:'
    [CmdletBinding()] 
    param (
        [Parameter(Position=0)]
        [string]$initialDirectory = './',
        [Parameter(Position=1)]
        [string]$defaultfilename = '',
        [Parameter(Position=2)]
        [string]$fileFilter = 'All files (*.*)| *.*',
        [Parameter(Position=3)] 
        [string]$titleDialog = ''
    )
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $SetBackupLocation = New-Object System.Windows.Forms.SaveFileDialog
    $SetBackupLocation.initialDirectory = $initialDirectory
    $SetBackupLocation.filter = $fileFilter
    $SetBackupLocation.FilterIndex = 2
    $SetBackupLocation.Title = $titleDialog
    $SetBackupLocation.RestoreDirectory = $true
    $SetBackupLocation.ShowHelp = if ($Host.name -eq 'ConsoleHost') {$true} else {$false}
    $SetBackupLocation.filename = $defaultfilename
    $SetBackupLocation.ShowDialog() | Out-Null
    return $SetBackupLocation.Filename
}

function Add-Array2Clipboard {
  param (
    [PSObject[]]$ConvertObject,
    [switch]$Header
  )
  process{
    $array = @()

    if ($Header) {
      $line =""
      $ConvertObject | Get-Member -MemberType Property,NoteProperty,CodeProperty | Select -Property Name | %{
        $line += ($_.Name.tostring() + "`t")
      }
      $array += ($line.TrimEnd("`t") + "`r")
    }
    foreach($row in $ConvertObject){
        $line =""
        $row | Get-Member -MemberType Property,NoteProperty | %{
          $Name = $_.Name
          if(!$Row.$Name){$Row.$Name = ""}
          $line += ([string]$Row.$Name + "`t")
        }
        $array += ($line.TrimEnd("`t") + "`r")
    }
    Set-ClipBoard $array
  }
}

function Select-Unique {
    # Select objects based on unique property
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [string[]] $Property,
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $InputObject,
        [Parameter()]
        [switch] $AsHashtable,
        [Parameter()]
        [switch] $NoElement
    )
 
    begin {
        $Keys = @{}
    }
 
    process {
        $InputObject | foreach-object {
            $o = $_
            $k = $Property | foreach-object -begin {
                    $s = ''
                } -process {
                    # Delimit multiple properties like group-object does.
                    if ( $s.Length -gt 0 ) {
                        $s += ', '
                    }
 
                    $s += $o.$_ -as [string]
                } -end {
                    $s
                }
 
            if ( -not $Keys.ContainsKey($k) ) {
                $Keys.Add($k, $null)
                if ( -not $AsHashtable ) {
                    $o
                }
                elseif ( -not $NoElement ) {
                    $Keys[$k] = $o
                }
            }
        }
    }
 
    end {
        if ( $AsHashtable ) {
            $Keys
        }
    }
}

function New-RegexFromRange {
    # Courtesy (mostly) of http://rxnrg.codeplex.com/
    [CmdletBinding()] 
    param (
        [Parameter(Position=0, Mandatory=$true, HelpMessage='Start of number range.')]
        [string]$startrange,
        [Parameter(Position=1, Mandatory=$true, HelpMessage='End of number range.')] 
        [string]$endrange
    )
    begin {
        $rxnrgCode = @'
            using System;
            using System.Collections.Generic;
            using System.Globalization;
            using System.Text;
            public class RegexNumRangeGen
            {
            	public static string Generate(string a, string b)
            	{
            		if (a == null)
            		{
            			throw new ArgumentNullException("a");
            		}

            		if (b == null)
            		{
            			throw new ArgumentNullException("b");
            		}

            		if (a.Length == 0 || TextHelper.IsDigit(a) != -1)
            		{
            			throw new ArgumentException("A is not a number.", "a");
            		}

            		if (b.Length == 0 || TextHelper.IsDigit(b) != -1)
            		{
            			throw new ArgumentException("B is not a number.", "b");
            		}

            		a = a.Remove(0, TextHelper.FindRep('0', a, 0, a.Length - 2));
            		b = b.Remove(0, TextHelper.FindRep('0', b, 0, b.Length - 2));

            		if (TextHelper.Compare(a, b) > -1)
            		{
            			string c = a;
            			a = b;
            			b = c;
            		}

            		return BuildRegex(Divide(new Range() { A = a, B = b }));
            	}

            	private static List<Range> Divide(Range fullRange)
            	{
            		int diff = TextHelper.Compare(fullRange.B, fullRange.A);
            		List<Range> ranges = new List<Range>();

            		if (diff == -1)
            		{
            			ranges.Add(fullRange);
            		}
            		else
            		{
            			List<Range> bigRanges = new List<Range>();

            			for (int i = fullRange.A.Length; i <= fullRange.B.Length; i++)
            			{
            				bigRanges.Add(new Range() { A = ((i == fullRange.A.Length) ? fullRange.A : "1" + new string('0', i - 1)), B = ((i == fullRange.B.Length) ? fullRange.B : new string('9', i)), IsBig = true });
            			}

            			Range range = bigRanges[0];

            			{
            				int len = range.A.Length - 1;

            				int x = 1 + TextHelper.FindRepRight('0', range.A, len, (diff == 0) ? 1 : diff);
            				int y = range.A.Length;

            				if (diff > 0)
            				{
            					y -= diff;
            				}

            				string a = range.A;

            				for (int i = x; i <= y; i++)
            				{
            					int b = i - 1;

            					if (i > x)
            					{
            						a = String.Concat(new string[] { a.Substring(0, a.Length - b - 1), ((char)(a[len - b] + 1)).ToString(), new string('0', b) });
            					}

            					i += TextHelper.FindRepRight('9', range.A, len - i, 0);

            					if (i > y)
            					{
            						i -= 1;
            					}

            					ranges.Add(new Range() { A = a, B = range.A.Substring(0, range.A.Length - i) + new string('9', i) });
            				}
            			}

            			{
            				int len = bigRanges.Count - 1;

            				for (int i = 1; i < len; i++)
            				{
            					ranges.Add(bigRanges[i]);
            				}
            			}

            			range = (diff == 0) ?
            				bigRanges[bigRanges.Count - 1] :
            				(ranges.Count == 0) ?
            				fullRange : new Range() { A = String.Concat(new string[] { fullRange.A.Substring(0, diff - 1), ((char)(fullRange.A[diff - 1] + 1)).ToString(), new string('0', fullRange.A.Length - diff) }), B = fullRange.B };

            			if (range.A == range.B)
            			{
            				ranges.Add(range);
            			}
            			else
            			{
            				int x = TextHelper.Compare(range.B, range.A);
            				int y = range.B.Length - TextHelper.FindRepRight('9', range.B, range.B.Length - 1, x);
            				string a = range.A;

            				for (int i = x; i <= y; i++)
            				{
            					if (i > x)
            					{
            						a = range.B.Substring(0, i - 1) + new string('0', range.B.Length - i + 1);
            					}

            					i += TextHelper.FindRep('0', range.B, i - 1, y - 1);

            					if (i > y)
            					{
            						i -= 1;
            					}

            					ranges.Add(new Range() { A = a, B = ((i == y) ? range.B : String.Concat(new string[] { range.B.Substring(0, i - 1), ((char)(range.B[i - 1] - 1)).ToString(), new string('9', range.B.Length - i) })) });
            				}
            			}
            		}

            		return ranges;
            	}

            	private static string BuildRegex(List<Range> ranges)
            	{
            		StringBuilder sb = new StringBuilder();

            		if (ranges.Count > 1)
            		{
            			sb.Append('(');
            		}

            		int rangesLen = ranges.Count - 1;

            		for (int rangesIndex = 0; rangesIndex <= rangesLen; rangesIndex++)
            		{
            			if (rangesIndex != 0)
            			{
            				sb.Append('|');
            			}

            			Range range = ranges[rangesIndex];

            			int length = range.A.Length;

            			for (int index = 0; index < length; index++)
            			{
            				char c1 = range.A[index];
            				char c2 = range.B[index];

            				if (c1 == c2)
            				{
            					sb.Append(c1);
            				}
            				else
            				{
            					sb.Append('[');
            					sb.Append(c1);

            					if (c2 - c1 != 1)
            					{
            						sb.Append('-');
            					}

            					sb.Append(c2);
            					sb.Append(']');

            					if (c1 == '0' && c2 == '9')
            					{
            						int oldRangesIndex = rangesIndex;

            						while (true)
            						{
            							if (rangesIndex == rangesLen)
            							{
            								Range newRange = ranges[rangesIndex];

            								if (rangesIndex != oldRangesIndex && TextHelper.FindRep('9', newRange.B, 0, newRange.B.Length - 1) != newRange.B.Length)
            								{
            									rangesIndex--;
            								}

            								break;
            							}
            							else if (!ranges[rangesIndex].IsBig)
            							{
            								if (rangesIndex != oldRangesIndex)
            								{
            									rangesIndex--;
            								}

            								break;
            							}

            							rangesIndex++;
            						}

            						int q1 = length - index;
            						int q2 = q1 + (rangesIndex - oldRangesIndex);

            						if (q1 > 1 || q2 > 1)
            						{
            							sb.Append('{');
            							sb.Append(q1.ToString(CultureInfo.InvariantCulture));

            							if (q2 > q1)
            							{
            								sb.Append(',');
            								sb.Append(q2.ToString(CultureInfo.InvariantCulture));
            							}

            							sb.Append('}');
            						}

            						break;
            					}
            				}
            			}
            		}

            		if (ranges.Count > 1)
            		{
            			sb.Append(')');
            		}

            		return sb.ToString();
            	}

            	private struct Range
            	{
            		public string A;
            		public string B;
            		public bool IsBig;
            	}

            	private static class TextHelper
            	{
            		private static int[] charmap = new int[]
            		{
            			1, 1, 1, 1, 1, 1, 1, 1, 1, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
            			1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 0, 0, 0, 0, 0, 0, 0,
            			0, 0, 0, 0, 0, 0, 0, 0, 36, 36, 36, 36, 36, 36, 36, 36, 36, 36, 0, 0,
            			0, 0, 0, 0, 0, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40,
            			40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 40, 0, 0, 0, 0, 32, 0, 48, 48, 48,
            			48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48,
            			48, 48, 48, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
            			1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1
            		};
            		private static int charmapLength = 160;

            		public static bool IsDigit(char c)
            		{
            			return ((c < charmapLength) && ((charmap[c] & 4) != 0));
            		}

            		public static int IsDigit(string s)
            		{
            			return Validate(s, IsDigit);
            		}

            		public static int Validate(string str, Func<char, bool> validator)
            		{
            			int length = str.Length;

            			for (int index = 0; index < length; index++)
            			{
            				if (!validator.Invoke(str[index]))
            				{
            					return index;
            				}
            			}

            			return -1;
            		}

            		public static int Compare(string str1, string str2)
            		{
            			if (str1.Length > str2.Length)
            			{
            				return 0;
            			}

            			if (str1.Length == str2.Length)
            			{
            				int length = str1.Length;

            				for (int index = 0; index < length; index++)
            				{
            					if (str1[index] > str2[index])
            					{
            						return index + 1;
            					}

            					if (str1[index] < str2[index])
            					{
            						return -3;
            					}
            				}

            				return -1;
            			}

            			return -2;
            		}

            		public static int FindRep(char chr, string str, int beginPos, int endPos)
            		{
            			int pos;

            			for (pos = beginPos; pos <= endPos; pos++)
            			{
            				if (str[pos] != chr)
            				{
            					break;
            				}
            			}

            			return pos - beginPos;
            		}

            		public static int FindRepRight(char chr, string str, int beginPos, int endPos)
            		{
            			int pos;

            			for (pos = beginPos; pos >= endPos; pos--)
            			{
            				if (str[pos] != chr)
            				{
            					break;
            				}
            			}

            			return beginPos - pos;
            		}
            	}
            }
        
'@
        try {
            Add-Type -ErrorAction Stop -Language:CSharpVersion3 -TypeDefinition $rxnrgCode
        }
        catch {
            Write-Error $_.Exception.Message
            break
        }
    }
    process {}
    end {
        [RegexNumRangeGen]::Generate($startrange,$endrange)
    }
}

function Get-NumberRangeOverlap {
    [CmdletBinding()] 
    param (
        [Parameter(Position=0, Mandatory=$true, HelpMessage='Start of number range.')]
        [int]$startrange1,
        [Parameter(Position=1, Mandatory=$true, HelpMessage='End of number range.')]
        [int]$endrange1,
        [Parameter(Position=3, Mandatory=$true, HelpMessage='Start of number range.')]
        [int]$startrange2,
        [Parameter(Position=4, Mandatory=$true, HelpMessage='End of number range.')]
        [int]$endrange2,
        [Parameter(Position=5, HelpMessage='Return only non-overlapping numbers instead.')]
        [switch]$InverseResults,
        [Parameter(Position=6, HelpMessage='Return if the match is source from range1 or range2')]
        [switch]$TagResults
    )
    $range1flipped = $false
    $range2flipped = $false
    if ($endrange1 -lt $startrange1) {
        $tmpendrange = $startrange1
        $startrange1 = $endrange1
        $endrange1 = $tmpendrange
        $range1flipped = $true
    }
    if ($endrange2 -lt $startrange2) {
        $tmpendrange = $startrange2
        $startrange2 = $endrange2
        $endrange2 = $tmpendrange
        $range2flipped = $true
    }
    
    # if there are no overlaps and we are not inversing results then there is nothing to do
    if ( -not 
        ((($startrange1 -le $endrange2) -and ($startrange1 -ge $startrange2)) -or 
        (($endrange1 -ge $startrange1) -and ($endrange1 -le $endrange2)) -or 
        (($startrange2 -le $endrange1) -and ($startrange2 -ge $startrange1)) -or 
        (($endrange2 -ge $startrange2) -and ($endrange2 -le $endrange1)))
       ) {
        if (-not $InverseResults) {
            break
        }
    }
    function Get-Results ($x, $tagged, $range) {
        if (-not $tagged) { $x }
        else { New-Object psobject -Property @{'range' = $range; 'number' = $x} }
    }
    $Results = @()
    # Check first range against second range
    for ($index = $startrange1; $index -le $endrange1; $index++) {
        $foundmatch = $false
        if (($index -ge $startrange2) -and ($index -le $endrange2)) {
            $foundmatch = $true
        }
        if ($foundmatch -and (-not $InverseResults)) { $Results += Get-Results $index $TagResults 'range1' }
        elseif ((-not $foundmatch) -and $InverseResults) { $Results += Get-Results $index $TagResults 'range1' }
    }
    if ($InverseResults) {
        for ($index = $startrange2; $index -le $endrange2; $index++) {
            $foundmatch = $false
            if (($index -ge $startrange1) -and ($index -le $endrange1)) {
                $foundmatch = $true
            }
            #if ($foundmatch -and (-not $InverseResults)) { $Results += Get-Results $index $TagResults 'range2' }
            if (-not $foundmatch) { 
                $Results += Get-Results $index $TagResults 'range2' }
        }
    }
    if ($TagResults) {
        $Results
    }
    else {
        $Results | Select -Unique
    }
}

function Convert-ToNumberRange {
    [CmdletBinding()] 
    param (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, HelpMessage='Range of numbers in array.')]
        [int[]]$series
    )
    begin {
        $numberseries = @()
    }
    process {
        $numberseries += $series
    }
    end {
        $numberranges = @()
        $numberseries = @($numberseries | Sort | Select -Unique)
        $index = 1
        $initmode = $true
        $start = $numberseries[0]
        if ($numberseries.Count -eq 1) {
            return New-Object psobject -Property @{
                'Begin' = $numberseries[0]
                'End' = $numberseries[0]
            }
        }
        do {
            if (-not $initmode) {
                if (($numberseries[$index] - $numberseries[$index - 1]) -ne 1) {
                    New-Object psobject -Property @{
                        'Begin' = $start
                        'End' = $numberseries[$index-1]
                    }
                    $start = $numberseries[$index]
                    $initmode = $true
                }
            }
            else {
                $initmode = $false
            }
            $index++
        } until ($index -eq ($numberseries.length))
        New-Object psobject -Property @{
            'Begin' = $start
            'End' = $numberseries[$index - 1]
        }
    }
}

function Get-SiteDialPlanOverlaps {
    [CmdletBinding()] 
    param (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, HelpMessage='Object containing number ranges.')]
        [psobject[]]$Obj,
        [Parameter(Position=1, HelpMessage='Number of trailing digits to use to compare number overlap ranges.')] 
        [uint64]$Digits=0
    )
    begin {
        $Ranges = @()
        $NewRanges = @()
        $TempRanges = @()
        $Count = 0
    }
    process {
        $Ranges += $Obj
    }
    end {
        $Ranges = $Ranges | Sort-Object -Property DIDStart

        Foreach ($DIDRange in $Ranges) {
            $tmpObj = $DIDRange.PsObject.Copy()
            $tmpObj | Add-Member -MemberType NoteProperty -Name Overlapped -Value $false
            $tmpObj | Add-Member -MemberType NoteProperty -Name Index -Value $Count
            $tmpObj | Add-Member -MemberType ScriptMethod -Name UpdateRanges -Value { 
                param ( 
                    [string]$start,
                    [string]$end
                ) 
                $this.DigitsStart = $start
                $this.DigitsEnd = $end
            }
            $tmpObj | Add-Member -MemberType ScriptMethod -Name ContainsRange -Value { 
                param ( 
                    [string]$start,
                    [string]$end
                ) 
                if (($this.DigitsStart -eq $start) -and ($this.DigitsEnd -eq $end) -or 
                    ($this.DigitsEnd -eq $start) -and ($this.DigitsStart -eq $end)) {
                    $true
                }
                else {
                    $false
                }
            }
            $NewRanges += $tmpObj
            $Count++
        }
        
        $NewRanges = $NewRanges | Sort-Object -Property DigitsStart
        if ($NewRanges.Count -gt 1) {
            do {
                $overlapsfound = $false
                for ($i = 0; $i -lt $NewRanges.Count; $i++) {
                	for ($i2 = $i; $i2 -lt $NewRanges.Count; $i2++) {
                	    if (($i -ne $i2) -and (-not $NewRanges[$i].Overlapped) -and (-not $NewRanges[$i2].Overlapped)) {
                            $overlap = @(Get-NumberRangeOverlap -startrange1 ('11' + $NewRanges[$i].'DigitsStart') `
                                                                -endrange1 ('11' + $NewRanges[$i].'DigitsEnd') `
                                                                -startrange2 ('11' + $NewRanges[$i2].'DigitsStart') `
                                                                -endrange2 ('11' + $NewRanges[$i2].'DigitsEnd'))
                            Write-Verbose "Test Ranges($i - $i2): $($NewRanges[$i].'DigitsStart')-$($NewRanges[$i].'DigitsEnd') and $($NewRanges[$i2].'DigitsStart')-$($NewRanges[$i2].'DigitsEnd')"
                            if ($overlap.count -ge 1) {
                                $overlaprange = $overlap | Convert-ToNumberRange
                                $_start = if ($overlaprange.Begin -match '^11(.*)$') {[string]$Matches[1]} else {[string]$overlaprange.Begin}
                                $_end = if ($overlaprange.End -match '^11(.*)$') {[string]$Matches[1]} else {[string]$overlaprange.End}
                                # If an overlap has been found then create new ranges consisting of:
                                # - The overlap range for the first set
                                $Count++
                                $tmpObj = $NewRanges[$i2].PsObject.Copy()
                                $tmpObj.Overlapped = $true
                                $tmpObj.Index = $Count
                                $tmpObj.UpdateRanges($_start,$_end)
                                $TempRanges += $tmpObj
                                $overlapsfound = $true

                                $tmpObj = $NewRanges[$i].PsObject.Copy()
                                $tmpObj.Overlapped = $true
                                $tmpObj.Index = $Count
                                $tmpObj.UpdateRanges($_start,$_end)
                                $TempRanges += $tmpObj
                                $overlapsfound = $true

                                $nonoverlap = @(Get-NumberRangeOverlap -startrange1 ('11' + $NewRanges[$i].'DigitsStart') `
                                                              -endrange1 ('11' + $NewRanges[$i].'DigitsEnd') `
                                                              -startrange2 ('11' + $NewRanges[$i2].'DigitsStart') `
                                                              -endrange2 ('11' + $NewRanges[$i2].'DigitsEnd') `
                                                              -InverseResults -TagResults)

                                # - The first range up to the overlap range
                                if (($nonoverlap | Where {$_.range -eq 'range1'}).Count -gt 0) {
                                    $nonoverlaprange = ($nonoverlap | Where {$_.range -eq 'range1'}).Number | Convert-ToNumberRange
                                    $_start = if ($nonoverlaprange.Begin -match '^11(.*)$') {[string]$Matches[1]} else {[string]$nonoverlaprange.Begin}
                                    $_end = if ($nonoverlaprange.End -match '^11(.*)$') {[string]$Matches[1]} else {[string]$nonoverlaprange.End}
                                    if (($TempRanges).Index -contains ($NewRanges[$i]).Index) {
                                        $TempRanges | Where {$_.Index -eq ($NewRanges[$i]).Index} | Foreach {
                                            $_.UpdateRanges($_start,$_end)
                                        }
                                    }
                                    else {
                                        $tmpObj = $NewRanges[$i].PsObject.Copy()
                                        $tmpObj.UpdateRanges($_start,$_end)
                                        $TempRanges += $tmpObj
                                    }
                                }

                                # - The second range up to the overlap range
                                if (($nonoverlap | Where {$_.range -eq 'range2'}).Count -gt 0) {
                                    $nonoverlaprange = ($nonoverlap | Where {$_.range -eq 'range2'}).Number | Convert-ToNumberRange
                                    $_start = if ($nonoverlaprange.Begin -match '^11(.*)$') {[string]$Matches[1]} else {[string]$nonoverlaprange.Begin}
                                    $_end = if ($nonoverlaprange.End -match '^11(.*)$') {[string]$Matches[1]} else {[string]$nonoverlaprange.End}
                                    if (($TempRanges).Index -contains ($NewRanges[$i2]).Index) {
                                        $TempRanges | Where {$_.Index -eq ($NewRanges[$i2]).Index} | Foreach {
                                            $_.UpdateRanges($_start,$_end)
                                        }
                                    }
                                    else {
                                        $tmpObj = $NewRanges[$i2].PsObject.Copy()
                                        $tmpObj.UpdateRanges($_start,$_end)
                                        $TempRanges += $tmpObj
                                    }
                                }
                            }
                            else {
                                if (-not (($TempRanges).Index -contains $NewRanges[$i].Index)) {
                                    $tmpObj = $NewRanges[$i] | Select *
                                    $TempRanges += $tmpObj
                                }
                                if ((-not (($TempRanges).Index -contains $NewRanges[$i2].Index)) -and 
                                    (-not $overlapsfound) -and 
                                    (($NewRanges.Count - 1) -eq $i2)
                                   ) {
                                    $tmpObj = $NewRanges[$i2].PsObject.Copy()
                                    $TempRanges += $tmpObj
                                }
                            }
                        }
                    }
                }
                $NewRanges = @()
                $TempRanges | Foreach {$NewRanges += $_.PsObject.Copy()}
            } While ($overlapsfound)
        }
        else {
            $tmpObj = $NewRanges.PsObject.Copy()
            $tmpObj | Add-Member -MemberType NoteProperty -Name Overlapped -Value $false
            $tmpObj | Add-Member -MemberType NoteProperty -Name Index -Value 1
            $NewRanges = $tmpObj
        }
        return $NewRanges
    }
}

function New-SiteDialPlanTransform {
    [CmdletBinding()] 
    param (
        [Parameter(Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, HelpMessage='Site code for intrasite calling.')]
        [string]$SiteDialCode = '',
        [Parameter(Position=1, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, HelpMessage='Site name.')]
        [string]$SiteName,
        [Parameter(Position=2, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, HelpMessage='Beginning of DID range.')] 
        [string]$DIDStart,
        [Parameter(Position=3, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, HelpMessage='End of DID range.')] 
        [string]$DIDEnd,
        [Parameter(Position=4, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, HelpMessage='Number of trailing digits to use for local dialing.')] 
        [uint64]$Digits=0
    )
    begin {
        $Entries = @()
        $Output = @()
    }
    process {
        $Entries += New-Object psobject -Property $PSBoundParameters
    }
    end {
        $Entries = $Entries | Sort-Object -Property DIDStart
        $Prefix = $null
        $RegexResults = @()
        $Count = 0
        Foreach ($DIDRange in $Entries) {
            $ExtStart = '11' + ($DIDRange.DIDStart).substring(($DIDRange.DIDStart).length - $DIDRange.Digits, $DIDRange.Digits)
            $ExtEnd = '11' + ($DIDRange.DIDEnd).substring(($DIDRange.DIDEnd).length - $DIDRange.Digits, $DIDRange.Digits)
            if ((($DIDRange.DIDStart).substring(0,($DIDRange.DIDStart).length - $DIDRange.Digits)) -ne $Prefix) {
                if ($Prefix -ne $null) {
                    if (($DIDRange.SiteDialCode -eq '') -or ($DIDRange.SiteDialCode -eq $null)) {
                        $IntraSiteRegex = $null
                    }
                    else {
                        $IntraSiteRegex = '^' + $DIDRange.SiteDialCode +'(' + ($RegexResults -join '|') + ')$'
                    }
                    $Output += New-Object psobject -Property @{
                        'EntryName' = $DIDRange.SiteName +'-' + $Count
                        'LocalExt' = '^(' + ($RegexResults -join '|') + ')$'
                        'InterSiteExt' = $IntraSiteRegex
                        'Transform' = '+' + $Prefix + '$1'
                    }
                    $Count++
                    $RegexResults = @()
                    $Prefix = ($DIDRange.DIDStart).substring(0,($DIDRange.DIDStart).length - $DIDRange.Digits)
                }
                else {
                    $Prefix = ($DIDRange.DIDStart).substring(0,($DIDRange.DIDStart).length - $DIDRange.Digits)
                }
            }
            # Create our regex from the ranges and strip out the dummy 'll' at the begining of the results
            $tmpRegex = New-RegexFromRange -startrange $ExtStart -endrange $ExtEnd
            if ($tmpRegex -match '^11(.*)$') {
                $tmpRegex = $Matches[1]
            }
            else {
                $tmpRegex = $tmpRegex -replace '\|11','|' -replace '\(11','' -replace '\)','' -replace '\(',''
            }
            $RegexResults += $tmpRegex 
        }
        if (($DIDRange.SiteDialCode -eq '') -or ($DIDRange.SiteDialCode -eq $null)) {
            $InterSiteRegex = $null
        }
        else {
            $InterSiteRegex = '^' + $DIDRange.SiteDialCode +'(' + ($RegexResults -join '|') + ')$'
        }
        $Output += New-Object psobject -Property @{
            'EntryName' = $DIDRange.SiteName +'-' + $Count
            'LocalExt' = '^(' + ($RegexResults -join '|') + ')$'
            'InterSiteExt' = $InterSiteRegex
            'Transform' = '+' + $Prefix + '$1'
        }

        $Output
    }
}

#Globals
$DIDs = @()
$NewNormRuleLocal = @'
New-CsVoiceNormalizationRule -Parent '<0>' -Name '<0>_<2>Digit-<1>' -Description 'Local <2> Digit local dialing for <0>' -Pattern '<3>' -Translation '<4>'
'@
$NewNormRuleInterSite = @'
New-CsVoiceNormalizationRule -Parent '<parent>' -Name '<0>_Intersite_<4>Digit-<1>' -Description 'Intersite <4> digit dialing for <0>' -Pattern '<2>' -Translation '<3>'
'@
$RemoveNormRuleKeepAll = @'
Remove-CsVoiceNormalizationRule -Identity 'Tag:<parent>/Keep All'
'@

$AddNormRuleKeepAll = @'
New-CsVoiceNormalizationRule -Parent '<parent>' -Name 'Keep All' -Pattern '^(\d+)$' -Translation '$1'
'@

$NewAnnouncementTemplate = @'
$AnnouncementServices = @{}
get-cspool | Where {$_.Services -like "ApplicationServer*"} | Foreach {
    $AnnouncementName = "UnassignedNumberAnnouncement-$(($_.fqdn -split '\.')[0])"
    $AnnouncementService = "service:ApplicationServer:$($_.fqdn)"
    $AnnouncementServices.$AnnouncementName = $AnnouncementService
    New-CsAnnouncement -Parent $AnnouncementService -Name "$AnnouncementName" -TextToSpeechPrompt '<prompt>' -Language "en-US"
}
'@

$NewCsUnassignedTemplate = @'
$AnnouncementServices.Keys | Foreach {
    $AnnouncementService = $AnnouncementServices.$_
    $AnnouncementName = $_
    $Poolname = $AnnouncementService -replace 'service:ApplicationServer:',''
    $Poolname = ($Poolname -split '\.')[0]
<unassignedranges>
}
'@
$NewCsUnassignedRange = @'
    New-CsUnassignedNumber -Identity "$($Poolname)_Unassigned_<sitename>_<count>" -NumberRangeStart '+<rangestart>' -NumberRangeEnd '+<rangeend>' -AnnouncementService $AnnouncementService -AnnouncementName $AnnouncementName
'@
if ([System.Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {               
    Write-Warning 'Run PowerShell.exe with -Sta switch, then run this script.'
    Write-Warning 'Example:'
    Write-Warning '    PowerShell.exe -noprofile -Sta'
    exit
}
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$xamlMain = @'
<Window x:Name="windowMain"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Zach Loeber's DID Normalizer Tool" Height="727.2" Width="1011.175" ResizeMode="NoResize" ScrollViewer.VerticalScrollBarVisibility="Disabled" IsTabStop="False">
    <Window.Resources>

    </Window.Resources>
    <Grid>
        <GroupBox Header="Direct Inward Dial" Margin="269,93,0,0" VerticalAlignment="Top" Height="77" HorizontalAlignment="Left" Width="204">
            <Grid Margin="0,-8,-3,-12.6" Height="75" VerticalAlignment="Top" HorizontalAlignment="Right" Width="195">
                <TextBox x:Name="txtLineNumberStart" HorizontalAlignment="Right" Margin="0,10,10,0" Width="118" FontSize="14" MaxLength="15" MaxLines="1" TextAlignment="Right" ToolTip="Start of DID range of numbers" Text="12223335555" Height="23" VerticalAlignment="Top" TabIndex="5"/>
                <TextBlock Margin="0,44,131,0" TextWrapping="Wrap" Text="DID End" VerticalAlignment="Top" HorizontalAlignment="Right" Width="55" Height="20" TextAlignment="Right"/>
                <TextBlock Margin="0,10,131,0" TextWrapping="Wrap" HorizontalAlignment="Right" Width="54" Height="24" VerticalAlignment="Top" Text="DID Start" TextAlignment="Right"/>
                <TextBox x:Name="txtLineNumberEnd" HorizontalAlignment="Right" Margin="0,42,10,0" Width="118" FontSize="14" MaxLength="15" MaxLines="1" TextAlignment="Right" ToolTip="End of DID range of numbers" Text="12223336666" Height="23" VerticalAlignment="Top" TabIndex="6"/>
            </Grid>
        </GroupBox>
        <Button x:Name="btnGenerate" Content="Generate!" HorizontalAlignment="Left" Margin="569,178,0,0" VerticalAlignment="Top" Width="81"/>
        <Button x:Name="btnRemove" Content="Remove" HorizontalAlignment="Left" Margin="81,179,0,0" VerticalAlignment="Top" Width="70"/>
        <GroupBox Header="Site" HorizontalAlignment="Left" Margin="10,93,0,0" VerticalAlignment="Top" Height="77" Width="255">
            <Grid Margin="-6,-7,2,-5.4">
                <TextBlock HorizontalAlignment="Left" Margin="11,13,0,0" TextWrapping="Wrap" Text="Site Name" VerticalAlignment="Top" Width="94" Height="23" TextAlignment="Right"/>
                <TextBox x:Name="txtSiteDialCode" HorizontalAlignment="Left" Margin="110,38,0,0" Width="126" FontSize="14" MaxLength="4" MaxLines="1" TextAlignment="Right" ToolTip="Used in other sites to reach this site (Site Dial Code + Site Local Digits)" Height="23" VerticalAlignment="Top" TabIndex="1"/>
                <TextBlock HorizontalAlignment="Left" Margin="10,41,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="95" Height="23" Text="Site Dial Code" TextAlignment="Right"/>
                <TextBox x:Name="txtSiteName" HorizontalAlignment="Left" Text="Site1" Width="126" FontSize="14" Margin="110,10,0,0" TextAlignment="Right" Height="23" VerticalAlignment="Top" TabIndex="0" ToolTip="Site Name. Used to arbitrarily name normalization rules."/>
            </Grid>
        </GroupBox>
        <Button x:Name="btnAdd" Content="Add" HorizontalAlignment="Left" Margin="10,179,0,0" VerticalAlignment="Top" Width="66"/>
        <ListView x:Name="listviewDIDs" HorizontalAlignment="Left" Height="124" Margin="10,203,0,0" VerticalAlignment="Top" Width="642" Grid.IsSharedSizeScope="True">
            <ListView.ContextMenu>
                <ContextMenu Name="ContextMenuInput"  StaysOpen="true">
                    <MenuItem Header="Copy" Name="MenuItemCopyInput"/>
                    <MenuItem Header="Clear" Name ="MenuItemClearInput"/>
                </ContextMenu>
            </ListView.ContextMenu>
            <ListView.ItemContainerStyle>
                <Style TargetType="{x:Type ListViewItem}">
                    <Setter Property="BorderBrush" Value="LightGray" />
                    <Setter Property="BorderThickness" Value="0,0,0,1" />
                </Style>
            </ListView.ItemContainerStyle>
            <ListView.View>
                <GridView>
                    <GridViewColumn Header="Site Name">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding SiteName}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="Site Dial Code">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding SiteDialCode}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="DID Start">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding DIDStart}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="DID End">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding DIDEnd}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="DID Prefix">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding DIDPrefix}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="Digits Start">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding DigitsStart}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="Digits End">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding DigitsEnd}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                </GridView>
            </ListView.View>
        </ListView>
        <GroupBox Header="Processing Options" HorizontalAlignment="Left" Margin="9,2,0,0" VerticalAlignment="Top" Height="91" Width="464">
            <Grid Margin="-6,-7,2,-5.4">
                <TextBlock HorizontalAlignment="Left" Margin="35,10,0,0" TextWrapping="Wrap" Text="Site Local Digits" VerticalAlignment="Top" Width="159" Height="17" FontSize="14"/>
                <TextBox x:Name="txtOptionLocalDigits" HorizontalAlignment="Left" Text="4" Width="20" MaxLength="3" Margin="8,11,0,0" TextAlignment="Center" Height="16" VerticalAlignment="Top" IsTabStop="False" ToolTip="Number of digits local site users can call to reach one another." TabIndex="0" RenderTransformOrigin="1.89,0.4" FontSize="10"/>
                <CheckBox x:Name="chkSimplifiedTransforms" Content="Simplified Transforms" HorizontalAlignment="Left" Margin="10,32,0,0" VerticalAlignment="Top" ToolTip="If you check this then normalization rules will be reduced to matching just the number of digits instead of an exact match." Height="16" FontSize="14" Width="184"/>
                <CheckBox x:Name="chkUnassignedRanges" Content="Create Unassigned Ranges" HorizontalAlignment="Left" Margin="10,53,0,0" VerticalAlignment="Top" ToolTip="Create a basic unassigned DID list" FontSize="14"/>
                <TextBlock HorizontalAlignment="Left" Margin="199,0,0,0" TextWrapping="Wrap" Text="Unassigned Announcement" VerticalAlignment="Top" Width="246" Height="17"/>
                <TextBox x:Name="txtAnnouncement" TextWrapping="Wrap" Text="The number you have called is not assigned to anyone. Please contact the main number for a directory listing." Margin="199,17,10.2,10.2"/>
            </Grid>
        </GroupBox>
        <ListView x:Name="listviewOutput" 
                  HorizontalAlignment="Left" 
                  Height="146" Margin="10,356,0,0" 
                  VerticalAlignment="Top" 
                  Width="640" 
                  Grid.IsSharedSizeScope="True">
            <ListView.ContextMenu>
                <ContextMenu Name="ContextMenuOutput"  StaysOpen="true">
                    <MenuItem Header="Copy" Name="MenuItemCopyResults"/>
                    <MenuItem Header="Clear" Name ="MenuItemClearResults"/>
                </ContextMenu>
            </ListView.ContextMenu>
            <ListView.ItemContainerStyle>
                <Style TargetType="{x:Type ListViewItem}">
                    <Setter Property="BorderBrush" Value="LightGray" />
                    <Setter Property="BorderThickness" Value="0,0,0,1" />
                </Style>
            </ListView.ItemContainerStyle>
            <ListView.View>
                <GridView>
                    <GridViewColumn Header="Entry Name">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding EntryName}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="Transform">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding Transform}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="Local Extension Match">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding LocalExt}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="Intersite Extension">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding InterSiteExt}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                </GridView>
            </ListView.View>
        </ListView>
        <Button x:Name="btnExit" Content="Exit" HorizontalAlignment="Left" Margin="906,674,0,0" VerticalAlignment="Top" Width="93"/>
        <ScrollViewer HorizontalAlignment="Left" Height="138" Margin="478,35,0,0" VerticalAlignment="Top" Width="172" VerticalScrollBarVisibility="Auto">
            <TextBlock x:Name="txtblockDescription" TextWrapping="Wrap" ScrollViewer.VerticalScrollBarVisibility="Auto" Background="#FFE8E2E2" IsManipulationEnabled="True"/>
        </ScrollViewer>
        <Label Content="Transformations (Turn these into dial plans)" HorizontalAlignment="Left" Margin="10,330,0,0" VerticalAlignment="Top" FontWeight="Bold" Width="255"/>
        <Label Content="Form Information/Status" HorizontalAlignment="Left" Margin="478,9,0,0" VerticalAlignment="Top" Width="172" FontWeight="Bold"/>
        <ListView x:Name="listviewDIDExceptions" HorizontalAlignment="Left" Height="131" Margin="10,538,0,0" VerticalAlignment="Top" Width="642" Grid.IsSharedSizeScope="True">
            <ListView.ContextMenu>
                <ContextMenu x:Name="ContextMenuInput1"  StaysOpen="true">
                    <MenuItem Header="Copy" x:Name="MenuItemCopyExceptions"/>
                    <MenuItem Header="Clear" x:Name ="MenuItemClearExceptions"/>
                </ContextMenu>
            </ListView.ContextMenu>
            <ListView.ItemContainerStyle>
                <Style TargetType="{x:Type ListViewItem}">
                    <Setter Property="BorderBrush" Value="LightGray" />
                    <Setter Property="BorderThickness" Value="0,0,0,1" />
                </Style>
            </ListView.ItemContainerStyle>
            <ListView.View>
                <GridView>
                    <GridViewColumn Header="Site Name">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding SiteName}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="Site Dial Code">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding SiteDialCode}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="DID Start">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding DIDStart}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="DID End">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding DIDEnd}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="DID Prefix">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding DIDPrefix}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="Digits Start">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding DigitsStart}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                    <GridViewColumn Header="Digits End">
                        <GridViewColumn.CellTemplate>
                            <DataTemplate>
                                <Label Content = "{Binding DigitsEnd}"/>
                            </DataTemplate>
                        </GridViewColumn.CellTemplate>
                    </GridViewColumn>
                </GridView>
            </ListView.View>
        </ListView>
        <Label Content="Exceptions (Duplicate Numbers You Should Not Use)" HorizontalAlignment="Left" Margin="9,507,0,0" VerticalAlignment="Top" FontWeight="Bold" Width="308"/>
        <Label Content="Instructions" HorizontalAlignment="Left" Margin="655,9,0,0" VerticalAlignment="Top" FontWeight="Bold" Width="83"/>
        <ScrollViewer HorizontalAlignment="Left" Height="313" Margin="657,356,0,0" VerticalAlignment="Top" Width="342">
            <TextBlock x:Name="txtblockExample" TextWrapping="Wrap" Background="#FFE8E2E2">
                <TextBlock.ContextMenu>
                    <ContextMenu StaysOpen="true">
                        <MenuItem Header="Copy" x:Name="MenuItemCopyExample"/>
                        <MenuItem Header="Clear" x:Name ="MenuItemClearExample"/>
                    </ContextMenu>
                </TextBlock.ContextMenu>
            </TextBlock>
        </ScrollViewer>
        <Label Content="Powershell Output" HorizontalAlignment="Left" Margin="655,332,0,0" VerticalAlignment="Top" FontWeight="Bold" Width="340"/>
        <WebBrowser x:Name="webbrowserInstructions" HorizontalAlignment="Left" Height="292" Margin="657,35,0,0" VerticalAlignment="Top" Width="338"/>
        <Button x:Name="btnSaveInput" Content="Save" HorizontalAlignment="Left" Margin="478,178,0,0" VerticalAlignment="Top" Width="86"/>
        <Button x:Name="btnLoad" Content="Load" HorizontalAlignment="Left" Margin="156,179,0,0" VerticalAlignment="Top" Width="70"/>
    </Grid>
</Window>
'@
$htmlInstructions = @'
<HTML><BODY>
<strong><span style="text-decoration: underline;">Author</span></strong>: Zachary Loeber <br/>

<strong><span style="text-decoration: underline;">Site</span></strong>: http://www.the-little-things.net <br/>

<strong><span style="text-decoration: underline;">Release Information</span></strong>

<p>01/08/2015 - Initial Release </p>

<strong><span style="text-decoration: underline;">Description</span></strong>

<p>This script is meant to ease the process of creating and deploying site local and intersite dial plans within Lync. The general idea is to enter in all the local site DID ranges with local site codes. Then, based on a digit count, create both the normalization rules needed for local dialing and for intersite dialing.</p>
<p>Example DID range data has been included which can be loaded for an initial test run. This data includes a few sites in the following format:</p>

<em><span style="text-decoration: underline;">Chicago</span></em>
<ol>
	<li>Local 4 Digit dialing</li>
	<li>New York 6 digit dialing (20 + ####)</li>
</ol>
<em><span style="text-decoration: underline;">New York</span></em>
<ol>
	<li>Local 4 digit dialing</li>
	<li>Chicago 6 digit dialing (10 + ####)</li>
</ol>
<em><span style="text-decoration: underline;">Global</span></em>
<ol>
	<li>New York 6 digit dialing (20 + ####)</li>
	<li>Chicago 6 digit dialing (10 + ####)</li>
</ol>
The example data purposefully includes some overlaps that might cause ambiguous results thus generating some exceptions for the exceptions list.

<strong><span style="text-decoration: underline;">Notes</span></strong>

Here are some important things to be aware of regarding this utility. It would behoove you to read through these:
<ul>
	<li>Ranges which are added that are exact duplicates will be ignored in processing.</li>
	<li>You can right-click and copy the contents of or clear any table in the form.</li>
	<li>Duplicate ranges can cause ambiguous transforms to occur so this utility attempts to isolate them and notify you to make exceptions in your DID assignments.</li>
	<li>The exceptions are chosen a bit arbitrarily. For any duplicate found between effective DID ranges (based on the site local digits defined) there will always be a duplicate found in at least two ranges. One of these will be marked for the exceptions list, the other will be processed for possible transformation. A carefully input set of ranges can be used to manipulate which ranges are chosen.</li>
	<li>The script output is meant to be a guideline and should be reviewed before running. What the script attempts to do is:</li>
</ul>
<ul>
	<li>Create a user scoped dial plan for each specified site</li>
	<li>Remove the catch-all normalization rule for the created dial plan</li>
	<li>Add local digit dialing normalization rules for each created dial plan</li>
	<li>Add intersite digit dialing to all created dial plans for other sites</li>
	<li>Add all intersite digit dialing normalization rules to the global dial plan as a fail safe for users which get created but are not assigned any site specific dial plan.</li>
</ul>
<ul>
	<li>This utility is not at all meant to be a replacement for the most excellent Lync Dialing Rule Optimizer (https://www.lyncoptimizer.com/) by Ken Lasko. It should compliment it well though. I’m actually going to say that if you don’t really understand Lync dial plans that you probably should refrain from using this or Ken’s tool until you do (I’ve inherited a few too many environments with wildly inappropriate or incorrect voice routing due to inexperienced engineers blindly running the optimizer’s results without truly understanding what they were inputting).</li>
	<li>The exceptions are listed with the original DID ranges but with the starting and ending digit columns updated to show the overlapped ranges (see screenshot).</li>
</ul>
</BODY></HTML>
'@

# Read XAML
$reader=(New-Object System.Xml.XmlNodeReader $xamlMain) 
$window=[Windows.Markup.XamlReader]::Load( $reader )

$namespace = @{ x = 'http://schemas.microsoft.com/winfx/2006/xaml' }
$xpath_formobjects = "//*[@*[contains(translate(name(.),'n','N'),'Name')]]" 

# Create a variable for every named xaml element
Select-Xml $xamlMain -Namespace $namespace -xpath $xpath_formobjects | Foreach {
    $_.Node | Foreach {
        Set-Variable -Name ($_.Name) -Value $window.FindName($_.Name)
    }
}

# Show instructions/info
$webbrowserInstructions.NavigateToString($htmlInstructions)

# Buttons (Apply, Cancel, et cetera)
$window.add_KeyDown({
    if ($args[1].key -eq 'Return') {
        #Apply changes or whatever else
    }
    elseif ($args[1].key -eq 'Escape') {
        if ((new-popup -message "Exit the application?" -title "Quit?" -Buttons "YesNo") -eq 6) { # 7 = No, 6 = Yes
            $windowMain.Close()
        }
    }
})

# Add in dynamic changing live help-like descriptions for each field.
$txtSiteName.add_GotKeyboardFocus({
    $txtblockDescription.Text = 'Site Name. Name dial plans and normalization rules.'
    $txtSiteName.SelectAll()
})
$txtSiteDialCode.add_GotKeyboardFocus({
    $txtblockDescription.Text = 'Used in other sites to reach this site (Site Dial Code + Site Local Digits)'
    $txtSiteDialCode.SelectAll()
})
$txtLineNumberStart.add_GotKeyboardFocus({
    $txtblockDescription.Text = "Start of DID range of numbers. `t`n`t`nThis is typically in the formate of: <Country Code> + <City Code> + <Area Code> + <DID Begin>`t`n`t`nExample: 15556667777"
    $txtLineNumberStart.SelectAll()
})
$txtLineNumberEnd.add_GotKeyboardFocus({
    $txtblockDescription.Text = "End of DID range of numbers. `t`n`t`nThis is typically in the formate of: <Country Code> + <City Code> + <Area Code> + <DID End>`t`n`t`nExample: 15556668888"
    $txtLineNumberEnd.SelectAll()
})
$txtOptionLocalDigits.add_GotKeyboardFocus({
    $txtblockDescription.Text = 'Number of digits local users of the site can call to reach one another.'
    $txtOptionLocalDigits.SelectAll()
})
$chkSimplifiedTransforms.add_GotKeyboardFocus({
    $txtblockDescription.Text = 'If you check this then normalization rules will be reduced to matching just the number of digits instead of an exact match if possible.'
    $txtOptionLocalDigits.SelectAll()
})
$chkUnassignedRanges.add_GotKeyboardFocus({
    $txtblockDescription.Text = 'Create a basic unassigned DID list (Not Completed Yet!)'
    $txtOptionLocalDigits.SelectAll()
})

$txtLineNumberStart.add_TextChanged({
    $this.Text = $this.Text -replace '\D'
})
$txtLineNumberEnd.add_TextChanged({
    $this.Text = $this.Text -replace '\D'
})
$txtOptionLocalDigits.add_TextChanged({
    $this.Text = $this.Text -replace '\D'
    if ($this.Text -ne '') {
        Reset-FormInputValidationState
        Recalculate-DIDRanges
    }
})

$btnExit.add_Click({
    if ((new-popup -message "Exit the application?" -title "Quit?" -Buttons "YesNo") -eq 6) {
        $windowMain.Close()
    }
})

$btnLoad.add_Click({
    $filename = Get-FileFromDialog -fileFilter 'CSV file (*.csv)|*.csv' -titleDialog "Select A CSV File:"
    if (($filename -ne '') -and (Test-Path $filename)) {
        $ImportData = Import-Csv $filename
        $HasAllColumns = $true
        $test = $ImportData[0]
        $listprops = @('SiteName','SiteDialCode','DIDStart','DIDEnd','DIDPrefix','DigitsStart','DigitsEnd')
        $listprops | Foreach {
            if (-not $test.PSObject.Properties.Match($_).Count) {
                $HasAllColumns = $false
            }
        }
        if ($HasAllColumns) {
            $listviewOutput.Items.Clear()
            $listviewDIDs.Items.Clear()
            $listviewDIDExceptions.Items.Clear()
            $ImportData | Foreach { 
                $listviewDIDs.Items.Add($_)
            }
            Reset-FormInputValidationState
        }
        else {
            New-Popup -Title 'Whoops!' -Message 'Missing columns from source data preventing the list from loading'
        }
    }
    
})

$btnSaveInput.add_Click({
    $filename = Save-FileFromDialog -defaultfilename 'did-backup.csv' -titleDialog 'Backup to a CSV file:' -fileFilter 'CSV file (*.csv)|*.csv'
    if ($filename -ne $null) {
        $listviewDIDs.Items | Export-Csv $filename -NoTypeInformation
    }
})

# Context menu item actions
$MenuItemClearResults.add_Click({
    $listviewOutput.Items.Clear()
})

$MenuItemCopyResults.add_Click({
    if ($listviewOutput.Items.Count -gt 0) {
        $OutputItems = $listviewOutput.Items | Select EntryName,InterSiteExt,LocalExt,Transform
        Add-Array2Clipboard -ConvertObject  $OutputItems -Header
    }
})

$MenuItemClearExceptions.add_Click({
    $listviewDIDExceptions.Items.Clear()
})

$MenuItemCopyExceptions.add_Click({
    if ($listviewDIDExceptions.Items.Count -gt 0) {
        $OutputItems = $listviewDIDExceptions.Items | Select SiteName,SiteDialCode,DIDStart,DIDEnd,DIDPrefix,DigitsStart,DigitsEnd
        Add-Array2Clipboard -ConvertObject  $OutputItems -Header
    }
})

$MenuItemClearInput.add_Click({
    $listviewDIDs.Items.Clear()
})

$MenuItemCopyInput.add_Click({
    if ($listviewDIDs.Items.Count -gt 0) {
        $InputItems = $listviewDIDs.Items | Select SiteName,SiteDialCode,DIDStart,DIDEnd,DIDPrefix,DigitsStart,DigitsEnd
        Add-Array2Clipboard -ConvertObject $InputItems -Header
    }
})

$MenuItemClearExample.add_Click({
    $txtblockExample.Text = ''
})

$MenuItemCopyExample.add_Click({
    Set-Clipboard $txtblockExample.Text
})

$btnAdd.add_Click({
    if (Set-FormInputValidationState) {
        $Digits = $txtOptionLocalDigits.text
        $DIDStart = $txtLineNumberStart.Text
        $DIDEnd = $txtLineNumberEnd.Text
        if (((($DIDStart).length - $Digits) -ge 0) -and ((($DIDEnd).length - $Digits) -ge 0)) {
            $DigitsStart = ($DIDStart).substring(($DIDStart).length - $Digits, $Digits)
            $DigitsEnd = ($DIDEnd).substring(($DIDEnd).length - $Digits, $Digits)
            $PrefixStart = ($DIDStart).substring(0,($DIDStart).length - $Digits)
            $PrefixEnd = ($DIDEnd).substring(0,($DIDEnd).length - $Digits)
            if ($PrefixStart -eq $PrefixEnd) {
                $tmpObj = New-Object psobject -Property @{
                    'SiteName' = $txtSiteName.Text
                    'SiteDialCode' = $txtSiteDialCode.Text
                    'DIDStart' = $txtLineNumberStart.Text
                    'DIDEnd' = $txtLineNumberEnd.Text
                    'DIDPrefix' = $PrefixStart
                    'DigitsStart' = $DigitsStart
                    'DigitsEnd' = $DigitsEnd
                }
                $listviewDIDs.Items.Add($tmpObj)
                Reset-FormInputValidationState
            }
            else {
                $txtOptionLocalDigits.BorderThickness=2
                $txtOptionLocalDigits.BorderBrush='#FFF21A11'
                $txtblockDescription.Text = 'This digit length would result in multiple (thus ambiguous) DID prefixes! To use this digit length please split this DID range so that all unique prefixes are in their own range.'
            }
        }
        else {
            $txtOptionLocalDigits.BorderThickness=2
            $txtOptionLocalDigits.BorderBrush='#FFF21A11'
            $txtblockDescription.Text = 'This digit length is greater than your DID size!'
        }
    }
})

$btnRemove.add_Click({
    if (($listviewDIDs.Items.Count -gt 0) -and ($listviewDIDs.SelectedIndex -ge 0)) {
        $listviewDIDs.Items.RemoveAt($listviewDIDs.SelectedIndex)
    }
})

$btnGenerate.add_Click({
    if (Validate-LocalDigitLength) {
        # Gather all our ranges for processing
        $tempDIDs = @()
        foreach ($item in $listviewDIDs.Items) {
            # Add a distinguishing property to filter out duplicates
            $tmpObj = $item.PsObject.Copy()
            $tmpObj | Add-Member -MemberType NoteProperty -Name FullRange -Value ($item.DIDStart + '-' + $item.DIDEnd)
            $tempDIDs += $tmpObj
        }

        # assuming we have stuff to work with then sort them out and process the entries by site code
        if ($tempDIDs.Count -gt 0) {
            $listviewDIDExceptions.Items.Clear()
            $listviewOutput.Items.Clear()
            $SiteCodes = $tempDIDs.SiteDialCode | Select -Unique
            $CreateDialPlans = "# Create per-site dial plans`t`n"
            $LocalDialPlanNormRules = "# Add local site dialing normalization rules to the dial plans`t`n"
            $IntersiteDialPlanNormRules = "# Add Intersite dialing normalization rules to the dial plans`t`n"
            $GlobalDialPlanNormRules = "# Add Global dialing normalization rules to the dial plans`t`n"
            $RemoveNormRules = "# Remove the catch all normalization rules (optional)`t`n"
            $AddNormRules = "# Re-add the catch all normalization rules so they end up last in the list`t`n"
            $UnassignedRanges = ""
            $SiteNorms = @{}
            $DupeDIDRanges = @()
            Foreach ($Site in $SiteCodes) {
                $TempIntersiteDialPlanNormRules = ''
                $NormCount = 1
                $SiteName = ($tempDIDs | Where {$_.SiteDialCode -eq $Site}).SiteName | Select -Unique
                $CreateDialPlans += "New-CsDialPlan -Identity `'$SiteName`'`t`n"
                $SiteDIDs = @($tempDIDs | Where {$_.SiteDialCode -eq $Site} | Sort-Object -Property DIDStart | Select-Unique -Property FullRange)
                
                # build up our unassigned ranges commands if applicable
                if ($chkUnassignedRanges.isChecked) {
                    $UnassignedCount = 1
                    $SiteDIDs | Foreach {
                        $UnassignedRanges += $NewCsUnassignedRange -replace '<sitename>',$_.SiteName `
                                                                   -replace '<count>',$UnassignedCount `
                                                                   -replace '<rangestart>',$_.DIDStart `
                                                                   -replace '<rangeend>',$_.DIDEnd
                        $UnassignedRanges += "`n"
                        $UnassignedCount++
                    }
                }
                
                if ($SiteDIDs.Count -gt 1) {
                    # Get any overlaps in all our ranges
                    $SplitDIDRanges = @(Get-SiteDialPlanOverlaps -Obj $SiteDIDs -Digits $txtOptionLocalDigits.text)
                }
                else {
                    $SplitDIDRanges = $SiteDIDs
                }
                $DupeDIDRangeSets = $SplitDIDRanges | Where {$_.Overlapped}
                $WorkingDIDRanges = @($SplitDIDRanges | Where {-not $_.Overlapped})
                
                Foreach ($DupeIndex in ($DupeDIDRangeSets.Index | Select -Unique)) {
                    $DupeSet = $DupeDIDRangeSets | Where {$_.Index -eq $DupeIndex} | Select SiteName,SiteDialCode,DIDStart,DIDEnd,DIDPrefix,DigitsStart,DigitsEnd
                    $DupeDIDRanges += $DupeSet[0]
                    $WorkingDIDRanges += $DupeSet[1]
                }
                
                $Transforms = @()
                if (($chkSimplifiedTransforms.IsChecked) -and ((($WorkingDIDRanges).DIDPrefix | Select -Unique).Count -eq 1)) {
                    $Transforms += New-Object psobject -Property @{
                        'EntryName' = $WorkingDIDRanges[0].SiteName +'-' + $txtOptionLocalDigits.text
                        'LocalExt' = '^(\d{' + $txtOptionLocalDigits.text + '})$'
                        'InterSiteExt' = '^(' + ($WorkingDIDRanges[0]).SiteDialCode + '\d{' + $txtOptionLocalDigits.text + '})$'
                        'Transform' = '+' + ($WorkingDIDRanges[0]).DIDPrefix + '$1'
                    }
                }
                else {
                    $Transforms += $WorkingDIDRanges | New-SiteDialPlanTransform -Digits $txtOptionLocalDigits.text
                }

                $TotalDigitCount = [int]($txtOptionLocalDigits.text) + (($WorkingDIDRanges[0]).SiteDialCode).length
                $Transforms | Foreach {
                    $LocalDialPlanNormRules += $NewNormRuleLocal -replace '<0>',$SiteName `
                                                             -replace '<1>',$NormCount `
                                                             -replace '<2>',$txtOptionLocalDigits.text `
                                                             -replace '<3>',$_.LocalExt `
                                                             -replace '<4>',$_.Transform
                    $LocalDialPlanNormRules += "`n"
                    if (($_.InterSiteExt -ne '') -and ($_.InterSiteExt -ne $null)) {
                        $TempIntersiteDialPlanNormRules += $NewNormRuleInterSite -replace '<0>',$SiteName `
                                                                             -replace '<1>',$NormCount `
                                                                             -replace '<2>',$_.InterSiteExt `
                                                                             -replace '<3>',$_.Transform `
                                                                             -replace '<4>',$TotalDigitCount
                        $TempIntersiteDialPlanNormRules += "`n"
                    }                                                 
                    $listviewOutput.Items.Add($_)
                    $NormCount++
                }
                if ($TempIntersiteDialPlanNormRules -ne '') {
                    # Keep a hash of intersite normalization rules for later
                    $SiteNorms.$SiteName = $TempIntersiteDialPlanNormRules
                }

                $AddNormRules = "# Re-add the catch all normalization rules so they end up last in the list`t`n"
            }
            # Create the intersite normalizations
            ForEach ($Site in ($tempDIDs.SiteName | Select -Unique)) {
                $SiteNorms.Keys | Foreach {
                    $IntersiteDialPlanNormRules += $SiteNorms.$_ -replace '<parent>',$Site
                }
                $GlobalDialPlanNormRules += $SiteNorms.$Site -replace '<parent>','Global'
                $RemoveNormRules += $RemoveNormRuleKeepAll -replace '<parent>',$Site
                $RemoveNormRules += "`n"
                $AddNormRules += $AddNormRuleKeepAll -replace '<parent>',$Site
                $AddNormRules += "`n"
            }
            
            # Display our powershell output
            $txtblockExample.text = $CreateDialPlans + "`n" + `
                                    $LocalDialPlanNormRules + "`n" + `
                                    $RemoveNormRules + "`n" + `
                                    $IntersiteDialPlanNormRules + "`n" + `
                                    $AddNormRules + "`n" + `
                                    $GlobalDialPlanNormRules + "`n"
            
            # Add unassigned ranges and announcements
            if ($chkUnassignedRanges.isChecked) {
                $NewCsAnnouncement = $NewAnnouncementTemplate -replace '<prompt>',$txtAnnouncement.Text
                $txtblockExample.text = $txtblockExample.text + "`n" + `
                                        $NewCsAnnouncement + "`n" + `
                                        ($NewCsUnassignedTemplate -replace '<unassignedranges>',$UnassignedRanges)
                                        
                                        
            }
            $DupeDIDRanges | Foreach {$listviewDIDExceptions.Items.Add($_)}
        }
    }
})

function Validate-LocalDigitLength {
    $minRangeLen = $null
    foreach ($item in $listviewDIDs.Items) {
        $tmpDIDLen = if (($item.DIDStart).Length -lt ($item.DIDEnd).Length) {($item.DIDStart).Length} else {($item.DIDEnd).Length}
        $minRangeLen = if ($minRangeLen -eq $null) {$tmpDIDLen} else {if ($tmpDIDLen -lt $minRangeLen) {$tmpDIDLen}}
    }
    
    if (($minRangeLen -lt $txtOptionLocalDigits.text) -and (-not ($minRangeLen -eq $null))) {
        $txtOptionLocalDigits.BorderThickness=2
        $txtOptionLocalDigits.BorderBrush='#FFF21A11'
        $txtblockDescription.Text = 'DID ranges are less digits than the site local digit count!'
        return $false
    }
    else {
        $txtOptionLocalDigits.BorderThickness=1
        $txtOptionLocalDigits.BorderBrush='#FFABADB3'
        return $true
    }
}

function Recalculate-DIDRanges {
    $Count = 0
    foreach ($item in $listviewDIDs.Items) {
        $Digits = $txtOptionLocalDigits.text
        $DIDStart = $item.DIDStart
        $DIDEnd = $item.DIDEnd
        $DigitsStart = ($DIDStart).substring(($DIDStart).length - $Digits, $Digits)
        $DigitsEnd = ($DIDEnd).substring(($DIDEnd).length - $Digits, $Digits)
        $PrefixStart = ($DIDStart).substring(0,($DIDStart).length - $Digits)
        $PrefixEnd = ($DIDEnd).substring(0,($DIDEnd).length - $Digits)
        if ($PrefixStart -eq $PrefixEnd) {
        	$listviewDIDs.Items[$Count].DIDPrefix = $PrefixStart
            $listviewDIDs.Items[$Count].DigitsStart = $DigitsStart
            $listviewDIDs.Items[$Count].DigitsEnd = $DigitsEnd
            $listviewDIDs.Items.Refresh()
            $txtOptionLocalDigits.BorderThickness=1
            $txtOptionLocalDigits.BorderBrush='#FFABADB3'
        }
        else {
            $txtOptionLocalDigits.BorderThickness=2
            $txtOptionLocalDigits.BorderBrush='#FFF21A11'
            $txtblockDescription.Text = 'This digit length would result in multiple (thus ambiguous) DID prefixes! To use this digit length please split this DID range so that all unique prefixes are in their own range.'
        }
        $Count++
    }
}

# Form specific functions
function Reset-FormInputValidationState {
    $txtSiteName.BorderThickness=1
    $txtSiteDialCode.BorderThickness=1
    $txtLineNumberStart.BorderThickness=1
    $txtLineNumberEnd.BorderThickness=1
    $txtOptionLocalDigits.BorderThickness=1

    $txtSiteName.BorderBrush='#FFABADB3'
    $txtSiteDialCode.BorderBrush='#FFABADB3'
    $txtLineNumberStart.BorderBrush='#FFABADB3'
    $txtLineNumberEnd.BorderBrush='#FFABADB3'
    $txtOptionLocalDigits.BorderBrush='#FFABADB3'
}

function Set-FormInputValidationState {
    $StatusOK = $true
    if ($txtSiteName.Text -eq '') {
        $StatusOK = $false
        $txtSiteName.BorderThickness=2
        $txtSiteName.BorderBrush='#FFF21A11'
        $txtblockDescription.Text = 'Please provide a site name!'
    }
    if ($txtLineNumberStart.Text -gt $txtLineNumberEnd.Text) {
        $StatusOK = $false
        $txtLineNumberStart.BorderThickness=2
        $txtLineNumberStart.BorderBrush.Color='#FFF21A11'
        $txtLineNumberEnd.BorderThickness=2
        $txtLineNumberEnd.BorderBrush='#FFF21A11'
        $txtblockDescription.Text = 'The end line number needs to come after the start line number!'
    }
    $SiteInfo = @($listviewDIDs.Items | Where {$_.SiteName -eq $txtSiteName.Text})
    if ($SiteInfo.Count -ge 1) {
        if ($txtSiteDialCode.Text -ne $SiteInfo[0].SiteDialCode) {
            $StatusOK = $false
            $txtSiteDialCode.BorderThickness=2
            $txtSiteDialCode.BorderBrush='#FFF21A11'
            $txtblockDescription.Text = 'It makes no sense to add the same site name with different site codes!'
        }
    }
    $SiteInfo = @($listviewDIDs.Items | Where {$_.SiteDialCode -eq $txtSiteDialCode.Text})
    if ($SiteInfo.Count -ge 1) {
        if ($txtSiteName.Text -ne $SiteInfo[0].SiteName) {
            $StatusOK = $false
            $txtSiteName.BorderThickness=2
            $txtSiteName.BorderBrush='#FFF21A11'
            $txtblockDescription.Text = 'It makes no sense to have the same site code assigned to multiple sites!'
        }
    }
    Return $StatusOK
}

# Due to some bizarre bug with showdialog and xaml we need to invoke this asynchronously 
#  to prevent a segfault
$async = $windowMain.Dispatcher.InvokeAsync({
    $windowMain.ShowDialog() | Out-Null
})
$async.Wait() | Out-Null

# Clear out previously created variables for every named xaml element to be nice...
Select-Xml $xamlMain -Namespace $namespace -xpath $xpath_formobjects | Foreach {
    $_.Node | Foreach {
        Remove-Variable -Name ($_.Name)
    }
}