using rssnews.Models;

namespace rssnews.GraphQL.Types
{
    public sealed class AuthorObject : ObjectType<Author>
    {
        protected override void Configure(IObjectTypeDescriptor<Author> descriptor)
        {
            descriptor.Name(nameof(Author));
            descriptor.Field(a => a.AuthorID).Type<StringType>();
            descriptor.Field(a => a.FirstName).Type<StringType>();
            descriptor.Field(a => a.LastName).Type<StringType>();
        }
    }
}