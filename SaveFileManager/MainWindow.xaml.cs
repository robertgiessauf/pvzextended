using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Navigation;
using System.Windows.Shapes;

namespace SaveFileManager;

/// <summary>
/// Interaction logic for MainWindow.xaml
/// </summary>
public partial class MainWindow : Window
{

    private ProfileManager manager = new ProfileManager();

    private PlayerDetails currentProfile;

    public MainWindow()
    {
        InitializeComponent();
        foreach (var profile in manager.SaveFiles.OrderBy(x => x.Seq))
        {
            this.saveFiles.Items.Add(profile);
        }
    }

    private void saveFiles_MouseDoubleClick(object sender, MouseButtonEventArgs e)
    {
        currentProfile = manager.Load(((PlayerInfo)saveFiles.SelectedItem).Id);
        var profile = currentProfile;
        tbCoins.Text = profile.Coins.ToString();
        tbLevels.Text = profile.Levels.ToString();
    }

    private void Button_Click(object sender, RoutedEventArgs e)
    {
        currentProfile.Coins = Convert.ToUInt32(tbCoins.Text);
        currentProfile.Levels = Convert.ToUInt32(tbLevels.Text);
        manager.Save(currentProfile, ((PlayerInfo)saveFiles.SelectedItem).Id);
    }
}